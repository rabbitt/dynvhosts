package DynVhosts::Apache2;

use strict;
use warnings FATAL => 'all';

use ModPerl::MethodLookup;
ModPerl::MethodLookup::preload_all_modules();

use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Connection ();
use Apache2::Log ();

use APR::UUID ();
use APR::Pool ();

use APR::Table ();

use ModPerl::Registry ();

use File::Spec::Functions qw(catfile);

use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

require 'DynVhosts/Apache2/Config.pm';

# PostReadRequest handles setting up the access and error log file as well as the document root
Apache2::ServerUtil->server->push_handlers('PerlPostReadRequestHandler' => 'DynVhosts::Apache2::Handlers::PostReadRequest');

use DynVhosts::Logging::Cache;
new DynVhosts::Logging::Cache(); # setup it up - hopefully shared between processes

1;
