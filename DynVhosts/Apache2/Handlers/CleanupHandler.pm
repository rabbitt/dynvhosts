package DynVhosts::Apache2::Handlers::CleanupHandler;

use strict;
use warnings FATAL => 'all';

use Fcntl qw(:flock);
use File::Spec::Functions qw(catfile);

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(:common);
use APR::Const    -compile => 'SUCCESS';

sub handler {
    my $r = shift;
    return Apache2::Const::DECLINED;
}

1;
