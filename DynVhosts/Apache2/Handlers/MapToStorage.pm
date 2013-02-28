package DynVhosts::Apache2::Handlers::MapToStorage;

use strict;
use warnings;

use Apache2::RequestRec();
use Apache2::RequestUtil();

use DynVhosts::Constants;
use DynVhosts::Domains;
use DynVhosts::Logging::Cache;

use Fcntl qw(:flock);
use Data::Dumper;

use Apache2::Const -compile => ':common';

sub handler {
    my $r = shift;
    return Apache2::Const::DECLINED;
}

1;
