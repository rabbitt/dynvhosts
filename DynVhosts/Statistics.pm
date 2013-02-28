package DynVhosts::Statistics;

use strict;
use warnings;

use Date::Format;

use DynVhosts::LogCache;
use DynVhosts::Constants;

# statistics gathering frequency (for database logging of statistics)
use constant STATS_DEFAULT_FREQUENCY => 30;

# make sure config is accessible via dump_stats
my %config = ();

# singleton - we only want one instance...
my $instance = undef;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	return $instance if ($instance);

	my $self = {
		'dbh'      => undef,
		'stats'    => {},
		'disabled' => FALSE,
	};

	$instance = bless($self, $class);
	$instance->_get_config();

	return $instance;
}

sub _get_config($$) {
	my $self = shift;

	my $options = DynVhosts::getOptions();

	eval "use Config::Simple;";
	if ($@) {
		warn "[vlogger] Unable to load Config::Simple - error was: $!\n\n";
		$self->{'disabled'} = TRUE;
		return;
	}

	eval 'Config::Simple->import_from($options->{db_config_file}, \%config);';

	if ($@ || ! $config{'statistics'}) {
		$self->{'disabled'} = TRUE;
		return;
	}

	%config = %{ $config{'statistics'} } || ();

	$config{'db_table'} ||= 'www-usage';
	$config{'db_port'}  ||= 3306 if lc($config{'db_type'}) eq 'mysql';
	$config{'frequency'} ||= STATS_DEFAULT_FREQUENCY;

	if (!$config{'db_user'} || !$config{'db_name'} ||
		!$config{'db_pass'} || !$config{'db_type'} || !$config{'db_host'}) {
			$self->{'disabled'} = TRUE;
	}
}

sub runnable($) { my $self = shift; return not $self->{'disabled'}; }

sub get($$) {
	return 0 if ($config{'disabled'}); # we're a noop if disabled is true
	my ($self, $vhost) = @_;
	return $self->{'stats'}{$vhost} || 0;
}

sub update($$) {
	return if ($config{'disabled'}); # we're a noop if disabled is true

	my ($self, $vhost, $bytes) = @_;
	$bytes = ($bytes eq '-' ? 0 : $bytes);

	return if (!$vhost || $bytes !~ /^\d+$/);
	$self->{'stats'}{$vhost} += $bytes;
}

sub get_stats_dbh() {
	return undef if ($config{'disabled'}); # we're a noop if disabled is true

	if (not $config{'dbh'}) {
		eval "use DBI;";
		if ($@) {
			warn "[vlogger] Unable to load DBI (disabling statistics) - error was: $!\n\n";
			$config{'disabled'} = TRUE;
			return;
		}
		my $dsn = 'dbi:' . $config{'db_type'} . ':' . $config{'db_name'}
				   . ':' . $config{'db_host'} . ':' . $config{'db_port'};

		$config{'dbh'} = DBI->connect($dsn, $config{'db_user'}, $config{'db_pass'});
	}

	return $config{'dbh'};

}

# sub to update the database with the tracker data
sub dump_stats {
	return if ($config{'disabled'}); # we're a noop if disabled is true

	my $db_table = $config{'db_table'};
	my $dbh      = get_stats_dbh();

	if ( keys(%{$config{'stats'}}) > 0 ) {

		my $select = $dbh->prepare("SELECT * FORM ${db_table} WHERE vhost=? AND ldate=?");
		my $update = $dbh->prepare("UPDATE ${db_table} SET bytes=(bytes + ?) WHERE vhost=? AND ldate=?");
		my $insert = $dbh->prepare("INSERT INTO ${db_table} (vhost, ldate, bytes) values (?, ?, ?)");

		my $ts = time2str("%m%d%Y", time());

		foreach my $vhost (keys(%{$config{'stats'}})) {
			$select->execute($vhost, $ts);
			if ($select->rows) {
				$update->execute($config{'stats'}->{$vhost}, $vhost, $ts);
			} else {
				$insert->execute($vhost, $ts, $config{'stats'}->{$vhost});
			}
		}

		$config{'stats'}->{'tracker'} = ();
	}

	setup_alarm();
}

1;
