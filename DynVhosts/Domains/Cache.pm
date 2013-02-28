package DynVhosts::Domains::Cache;

use strict;
use warnings;

use DynVhosts::Constants;

use Carp qw(cluck);
use Date::Format;

use IO::Handle;
use File::Path;
use Fcntl ':flock';

my %instances = ();

sub new($$) {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $path = shift || '';

	if (not $instances{$path}) {
		my $domains = get_domain_list($path);
		$instances{$path} = bless({ 'path' => $path, 'domains' => $domains }, $class);
	}
	return $instances{$path};
}

sub update_domain_list($) {
	my ($self) = @_;
	$self->{'domains'} = get_domain_list($self->{'path'});
}

sub get_domain_list($) {
	my $path = shift;

	$path = readlink($path) if ( -l $path );

	my @domains = ();
	if (-f $path) {
		my $text = do { local( @ARGV, $/ ) = $path; <> };
		@domains = split(/\s+/, lc($text));
	} elsif (-d $path) {
		opendir(DIR, $path) || die "can't opendir $path: $!";
		@domains = grep { /^[a-zA-Z0-9]/ && (-d "$path/$_" || -l "$path/$_") } readdir(DIR);
		closedir(DIR);
	} else {
		cluck "Can't handle path '$path' - not a valid file or directory!\n";
	}

	return \@domains;
}

my %vhost_parts = ();

sub get_domain_parts($$) {
	my ($self, $vhost) = @_;

	$vhost = lc($vhost);
	my %parts = ( '*' => $vhost, 'domain' => $vhost );

	if (!exists $vhost_parts{$vhost}) {

		my $domain = (grep { my $dom = $_; $vhost =~ m%(\.$dom$|^$dom$)%i } @{ $self->{'domains'} })[0] || undef;
		return \%parts if not defined($domain);

		my ($hostpart) = $vhost =~ /^(.*)\.$domain$/i;
		$hostpart ||= 'www'; # default to www

		my @parts = reverse split(/\./, $hostpart);

		$parts{'domain'} = $domain;
		$parts{'*<0'}  = $hostpart;

		my $i = 1;
		my @sparts = ();
		my (@forward, @back) = ();

		foreach my $part (@parts) {
			push @forward, $parts[$i-1];
			#unshift @back, $parts[$i-1];

			$parts{"$i"}  = $part;
			$parts{"$i>0"} = join('.', reverse(@forward));
			$parts{"$i*"} = join('.', (reverse(@forward), $domain));

			$i += 1;
		}

		$vhost_parts{$vhost} = \%parts;
	}

	return $vhost_parts{$vhost};
}

1;
