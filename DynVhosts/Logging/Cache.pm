package DynVhosts::Logging::Cache;

use strict;
use warnings;

use Apache2::ServerUtil ();
use Apache2::Module ();
use Apache2::RequestUtil ();

use DynVhosts::Constants;
use DynVhosts::Domains;
use DynVhosts::Utilities;

use Date::Format;

use File::Path;
use File::Spec::Functions qw(catfile catdir);

use IO::Handle;
use Fcntl ':flock';

use Data::Dumper;
our $instance = undef;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $config = shift || undef;

	if (not $instance) {
		$instance = bless({
			'config' => $config,
			'handles' => {},
			'last_timeperiod' => time()}, $class
		);
	} else {
		$instance->set_config($config) if ($config);
	}

	return $instance;
}

sub set_config($$) {
	my ($self, $config) = @_;
	$self->{'config'} = $config;
}

sub setup_path($$) {
	my ($self, $path) = @_;
	($path) = $path =~ /(.*)/;
	mkpath($path) unless (-d $path);
}

# static method
sub get_template_filename($) {
	my ($self) = @_;
	my $schedule = $self->{'config'}->{'logging_schedule'};
	return time2str($rotate_templates{$schedule} . '-access.log', time());
}

sub clear($) {
	my $self = shift;
	for my $key (keys(%{$self->{'handles'}})) {
		$self->close($key);
	}
	$self->{'handles'} = {};
}

sub getfd_lock($$) {
	my ($self, $vhost) = @_;
	return $self->getfd($vhost, 'excl-lock' => DynVhosts::Constants::TRUE);
}

sub unlock_fd($$) {
	my ($self, $fd) = @_;
	flock($fd, LOCK_UN);
}

sub close($$) {
	my ($self, $vhost) = @_;
	if (exists $self->{'handles'}{$vhost} && $self->{'handles'}{$vhost}) {
		# don't let someone else try to use it while we're closing it
		flock($self->{'handles'}{$vhost}, LOCK_EX);

		$self->{'handles'}{$vhost}->close();
		delete($self->{'handles'}{$vhost});

		return DynVhosts::Constants::TRUE;
	}
	return DynVhosts::Constants::FALSE;
}

sub getfd($$;%) {
	my ($self, $vhost, %options) = @_;

	if (!defined($vhost)) {
		$vhost = 'invalid.domain.tld';
	}

	# open a handle automatically if it doesn't exist
	$options{'auto-open'} = DynVhosts::Constants::TRUE unless defined($options{'auto-open'});
	$options{'excl-lock'} = DynVhosts::Constants::FALSE unless defined($options{'excl-lock'});

	# if a handle isn't yet open for this vhost, open one
	if (not exists $self->{'handles'}{$vhost} && $options{'auto-open'}) {
		$self->open_log($vhost);
	}

	if (not exists $self->{'handles'}{$vhost}) {
		warn "[DynVhosts] No open log file handle for domain [$vhost] - skipping...\n";
		return undef;
	}

	if ($options{'excl-lock'}) {
		flock($self->{'handles'}{$vhost}, LOCK_EX);

		if (! $self->{'handles'}{$vhost}) {
			# lost the file handle - reopen it
			$self->open_log($vhost);
		} else {
			# otherwise, seek to the end in case someone
			# appended while we were waiting, seek to the end
			seek($self->{'handles'}{$vhost}, 0, 2);
		}
	}
	return $self->{'handles'}{$vhost};
}

sub open_log($$) {
	my ($self, $vhost) = @_;

	my $domcache = new DynVhosts::Domains($self->{'config'}->{'domain_list'});
	my $log_path  = $domcache->interpolate_domain_path($vhost, $self->{'config'}->{'logging_base'});
	my $autoflush = $self->{'config'}->{'logging_autoflush'};
	my $filename  = $self->get_template_filename();

	if ($log_path !~ m|^/|) {
		# if it's a relative path, then prepend the server root
		$log_path = catfile Apache2::ServerUtil::server_root(), $log_path;
	}

	no warnings 'uninitialized';
	my $max_files = ($self->{'config'}->{'logging_max_files_open'} > 0 ? $self->{'config'}->{'logging_max_files_open'} : 15);

	# check how many files we have open, close the oldest
	# one if we're at or over our limit
	if ( keys(%{$self->{'handles'}}) >= $max_files) {

		my ( $key, $value ) = sort {
			# compare mtimes to find oldest written too
			(stat($self->{'handles'}{$a}))[9] <=> (stat($self->{'handles'}{$b}))[9]
		} ( keys(%{$self->{'handles'}}) );

		$self->{'handles'}{$key}->close();
		delete($self->{'handles'}{$key});
	}

	# create the logging path for the virtualhost if it doesn't exist
	$self->setup_path($log_path) unless (-d $log_path);

	open my $fd, '>>', "$log_path/$filename" or die("Can't open $log_path/$filename - error was: $!");

	$fd->autoflush(DynVhosts::Constants::TRUE) if ($autoflush);

	$self->{'handles'}{$vhost} = $fd;

	$self->do_symlink($log_path, $filename);
}

sub do_symlink($$$) {
	my ($self, $log_path, $filename) = @_;

	my $link_file = "$log_path/access.log";

	unlink($link_file) if (-l $link_file);
	symlink($filename, $link_file);
}

sub rotate($$) {
	my ($self, $vhost) = @_;

	my $schedule = $self->{'config'}->{'logging_schedule'};
	return if ($schedule == ROTATE_NEVER);

	# attempt to get the current vhost's file descriptor if we don't get
	# anything back, then we don't need to rotate this file - so let the
	# next getfd() create it on it's own.
	return if (!(my $fd = $self->getfd($vhost, 'auto-open' => DynVhosts::Constants::FALSE)));

	if ($schedule == ROTATE_ONSIZE) {
		if (-s $fd >= $self->{'config'}->{'max_file_size'}) {
			$self->close($vhost);
		}
	} else {
		my $template = undef;
		$template = '%Y%m%d' if ($schedule == ROTATE_DAILY);
		$template = '%Y%U' if ($schedule == ROTATE_WEEKLY);
		$template = '%Y%m' if ($schedule == ROTATE_MONTHLY);
		$template = '%Y' if ($schedule == ROTATE_YEARLY);

		if (defined($template)) {
			if (time2str($template, $self->{'last_timeperiod'}) < time2str($template, time())) {
				$self->close($vhost);
			}
		}
	}
}

DynVhosts::Constants::TRUE;
