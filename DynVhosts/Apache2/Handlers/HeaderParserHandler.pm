package DynVhosts::Apache2::Handlers::HeaderParserHandler;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::SubRequest ();
use APR::Finfo ();

use APR::Const -compile => qw(FINFO_NORM);
use Apache2::Const -compile => qw(DIR_MAGIC_TYPE OK DECLINED :common);

use DynVhosts::Constants;
use DynVhosts::Domains;
use DynVhosts::Logging::Cache;

use Fcntl qw(:flock);
use File::Spec::Functions qw(catfile);

sub handler {
    my $r = shift;
    return Apache2::Const::DECLINED;
}

1;
