package DynVhosts::Config::Apache2;

use strict;
use warnings;

use base 'DynVhosts::Config';

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;
