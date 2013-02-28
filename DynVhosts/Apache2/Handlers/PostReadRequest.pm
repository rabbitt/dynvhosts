package DynVhosts::Apache2::Handlers::PostReadRequest;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::SubRequest ();
use APR::Finfo ();

use APR::Const -compile => qw(FINFO_NORM SUCCESS);
use Apache2::Const -compile => qw(DIR_MAGIC_TYPE OK DECLINED :common LOG_CRIT);

use DynVhosts::Constants;
use DynVhosts::Domains;
use DynVhosts::Logging::Cache;
use DynVhosts::Utilities;

use Fcntl qw(:flock);
use File::Spec::Functions qw(catfile catdir);
use IO::Socket;

sub handler {
	my $r = shift;
	my $s = $r->server;

	my $srv_cfg = Apache2::Module::get_config('DynVhosts::Apache2::Config', $r->server, $r->per_dir_config);

	# make the request globally available from here on out
	Apache2::RequestUtil->request($r);

	# set up the domain path if dynvhost_state is set to 'on' (aka true, or 1)
	if ($srv_cfg->{'state'}) {

		# check the ip of the requested hostname
		# XXX: NEED TO CACHE THE gethostbyname() REQUESTS!!!
		my $ip_address;
		my $packed_ip = gethostbyname($r->hostname());
		if (defined $packed_ip) {
			$ip_address = inet_ntoa($packed_ip);
		} else {
			$ip_address = '';
		}

		my $domcache = new DynVhosts::Domains($srv_cfg->{'domain_list'});

		# make sure the domain requested is one that we are actually authoritative for
		# if not, it's an invalid domain - so handle it as such
		if (!in_array($ip_address, @{$srv_cfg->{'host_ips'}})) {
			$r->pnotes('invalid_domain', my $tmp = TRUE);

			# if it's invalid, then we use the base docroot + invalid-domain/www/htdocs
			# this allows us to create some fun pages for these requests
			# XXX: Invalid Domain document root path should be configurable
			$r->document_root($domcache->interpolate_domain_path('invalid-domain', $srv_cfg->{'document_root'}));

		} else {
			$r->pnotes('invalid_domain', my $tmp = FALSE);

			# we have a valid domain whom we are authoritative for - go ahead and process it normally
			$r->document_root($domcache->interpolate_domain_path($r->hostname, $srv_cfg->{'document_root'}));
			handle_catchall($r) unless -e $r->document_root();

			if ( ! -e $r->document_root()) {
				# at this point, we /know/ we're authoritative for this domain - however, the
				# domain doesn't have a base directory nor a catchall so let's shuffle it off to the
				# "unconfigured" document root path
				# XXX: Unconfigured Domain document root path should be configurable
				$r->document_root($domcache->interpolate_domain_path('not-configured', $srv_cfg->{'document_root'}));
			}
		}
	}

	if ($srv_cfg->{'logging'}) {
		# turn on logging
		$r->server->push_handlers('PerlLogHandler' => 'DynVhosts::Apache2::Handlers::LogHandler');
	}

	# we're not authoritative - let other handlers run
	return Apache2::Const::DECLINED;
}

sub handle_catchall {
	my $r = shift;
	my $srv_cfg = Apache2::Module::get_config('DynVhosts::Apache2::Config', $r->server, $r->per_dir_config);

	my $document_root = $r->document_root();
	if (! -d $document_root && ! -l $document_root) {
		my ($filepath) = $r->uri =~ m|^/?(.*)|;

		if ($srv_cfg->{'state'} && $srv_cfg->{'domain_catchall'}) {
			my $domcache = new DynVhosts::Domains($srv_cfg->{'domain_list'});
			my $catchall = $domcache->interpolate_domain_path($r->hostname, $srv_cfg->{'domain_catchall'});
			$document_root = $catchall if (-d $catchall || -l $catchall);
			$r->document_root($document_root);
		}

		$filepath = catfile $document_root, ($filepath eq '/' ? '' : $filepath);

		if (-f $filepath || -d $filepath || -l $filepath) {
			$filepath =~ s|/+|/|g;
			$r->filename($filepath);
			$r->finfo(APR::Finfo::stat($filepath, APR::Const::FINFO_NORM, $r->pool));
		}
	}

	return True;
}

1;
