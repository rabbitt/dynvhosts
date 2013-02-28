package DynVhosts::Domains;

use strict;
use warnings;

use Data::Dumper;

use DynVhosts::Domains::Cache;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $cache_path = shift;

    my $domain_cache = new DynVhosts::Domains::Cache($cache_path);

    return bless({'cache' => $domain_cache} , $class);
}

sub interpolate_domain_path($$$) {
    my ($self, $vhost, $path) = @_;

    $vhost = lc($vhost);

    my %parts = %{ $self->{'cache'}->get_domain_parts($vhost) };

    map {
        my $search = "\Q$_\E";
        $path =~ s|{{$search}}|$parts{$_}|ig;
    } keys %parts;

    return $path;
}

sub get_domain_parts($$) {
    my ($self, $vhost) = @_;
    return $self->{'cache'}->get_domain_parts($vhost);
}

sub update_cache($$) {
    my ($self) = @_;
    return $self->{'cache'}->update_domain_list();
}
1;
