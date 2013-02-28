package DynVhosts::Apache2::Handlers::LogHandler;

use strict;
use warnings;

use Data::Dumper;
use Date::Format;

use Apache2::ServerRec ();
use Apache2::RequestRec ();
use Apache2::Connection ();

use Fcntl qw(:flock);
use File::Spec::Functions qw(catfile);

use DynVhosts::Constants;
use DynVhosts::Logging::Cache;

use Apache2::Const -compile => qw(:common);

my $default_log_format  = q[%h %l %u %t "%r" %>s %b];
my $combined_log_format = q[%v %h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"];

## below taken from Apache::DBILogConfig
my %Formats = (
    # Remote IP Address
    'a' => sub {return (shift)->connection->remote_ip},
    # Local IP-address
    'A' => sub {},
    # Bytes sent, excluding heaers, in CLF format
    'b' => sub {return (shift)->bytes_sent || '-'},
    # Bytes sent, excluding headers
    'B' => sub {return (shift)->bytes_sent},
    # Connection status when response is completed (X, +, -)
    'c' => sub {},
    # Any environment variable
    'e' => sub {return (shift)->subprocess_env(shift)},
    # Filename
    'f' => sub {return (shift)->filename},
    # Remote host
    'h' => sub {return (shift)->connection->get_remote_host},
    # The request protocol
    'H' => sub {return (shift)->protocol},
    # A header in the client request
    'i' => sub {return (shift)->headers_in->get(shift)},
    # Remote log name (from identd)
    'l' => sub {return (shift)->get_remote_logname || '-' },
    # The request method
    'm' => sub {return (shift)->method},
    # The contents of a note from another module
    'n' => sub {return (shift)->notes(shift)},
    # A header from the reply
    'o' => sub {return (shift)->headers_out->get(shift)},
    # Server port
    'p' => sub {return (shift)->connection->local_addr->port()},
    # Apache child PID
    'P' => sub {return $$},
    # The query string (prepended with a ? if the query exists)
    'q' => sub {return $_[0]->args ? '?' . $_[0]->args : ''},
    # First line of the request
    'r' => sub {return (shift)->the_request},

    # Status (always the original request status - not the subrequest)
    '>s' => sub {return (shift)->status},
    's'  => sub {return (shift)->status},

    # Time: CLF or strftime
    't' => sub {return time2str $_[1] || "[%d/%b/%Y:%X %z]", $_[0]->request_time},
    # Time taken to serve the request
    'T' => sub {return time - (shift)->request_time},
    # Remote user from auth
    'u' => sub {return (shift)->user || '-' },
    # URL
    'U' => sub {return (shift)->uri},
    # The canonical ServerName
    'v' => sub {return (shift)->hostname},
    # The UseCanonicalName server name
    'V' => sub {return (shift)->server->server_hostname}
);

sub parse_log_format($$) {
    my ($request, $format) = @_;

    my @interpolated = ();
    my @options = split(/\s+/, $format);

    my $format_regex = join('|', map { "\Q$_\E" } keys  %Formats);
    foreach my $option (split(/\s+/, $format)) {
        {
            no warnings 'uninitialized';
            $option =~ s/%(\{([^\}]+)\})?($format_regex)/$Formats{$3}($request, (defined($2) ? $2 : ''))/ge;
            push @interpolated, $option;
        }
    }
    return @interpolated if wantarray;
    return join(' ', @interpolated);
}

sub handler {
    my $r = shift;

    my $srv_cfg = Apache2::Module::get_config('DynVhosts::Apache2::Config', $r->server, $r->per_dir_config);

    if (!$r->pnotes('done') && $srv_cfg->{'logging'} && $srv_cfg->{'logging_schedule'} != ROTATE_NEVER) {
            my $entry;
            my $hostname;

            if ($r->pnotes('invalid_domain')) {
                # log the request Hostname if we got an invalid domain request
                $entry = parse_log_format($r, $combined_log_format);
                $hostname = 'invalid-domain';
            } else {
                $entry = parse_log_format($r, $srv_cfg->{'logging_format'});
                $hostname = $r->hostname();
            }

            my $logcache = new DynVhosts::Logging::Cache($srv_cfg);
            $logcache->rotate($hostname);

            my $log_fd = $logcache->getfd_lock($hostname);
            print $log_fd $entry . "\n";
            $logcache->unlock_fd($log_fd);

            # make sure we only do the logging once per request
            # pnotes are perfect for this because they are automagically
            # disposed of at the end of the request
            $r->pnotes('done', my $tmp = 1);
    }
    return Apache2::Const::DECLINED;
}



1;
