package DynVhosts::Apache2::Handlers::FixupHandler;

use strict;
use warnings;

use Apache2::RequestRec();
use Apache2::RequestUtil();
use APR::Finfo ();

use DynVhosts::Domains;
use DynVhosts::Logging::Cache;

use Fcntl qw(:flock);

use APR::Const -compile => qw(FINFO_NORM);
use Apache2::Const -compile => ':common';
use Apache2::Const -compile => qw(DIR_MAGIC_TYPE OK DECLINED);

sub handler {
	my $r = shift;
	return Apache2::Const::DECLINED;
}

1;
