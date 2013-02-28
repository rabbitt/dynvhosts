package DynVhosts::Apache2::Config;

use strict;
use warnings FATAL => 'all';

use Apache2::CmdParms();
use Apache2::Module();
use Apache2::ServerUtil();
use Apache2::Directive();
use Apache2::Const -compile => qw(OK RSRC_CONF OR_OPTIONS TAKE1 FLAG ITERATE);

use DynVhosts::Constants;

use IO::Socket;
use IO::Interface qw(:flags);

my @ips = ();
my $s = IO::Socket::INET->new(Proto => 'udp');
my @interfaces = $s->if_list;

for my $if (@interfaces) {
    my $flags = $s->if_flags($if);
    # add each public ip we have that is currently running
    push @ips, $s->if_addr($if) if ($flags & IFF_RUNNING);

    # use the following if we want to dissallow loopback interface ips
    #push @ips, $s->if_addr($if) if ($flags & IFF_RUNNING && !($flags & IFF_LOOPBACK));
}

my $defaults = {
    state             => On,
    domain_list       => '/var/www/dynamic-vhosts',
    document_root     => '/var/www/dynamic-vhosts/{{domain}}/{{*<0}}/htdocs',
    domain_catchall   => '/var/www/dynamic-vhosts/{{domain}}/__catchall__/htdocs',
    host_ips          => \@ips,

    logging                => Off,
    logging_format         => q[%h %l %u %t "%r" %>s %b],
    logging_base           => 'logs/dynamic-vhosts',
    logging_schedule       => 'weekly',
    logging_max_files_open => 25,
    logging_max_file_size  => 0,
    logging_gzip_on_rotate => True,
    logging_autoflush      => True,
};

# (RSRC) DynVhosts_State            On|Off
# (RSRC) DynVhosts_DocumentRoot     "{{domain}}/{{subdomain-all}}/htdocs"
# (RSRC) DynVhosts_DomainList       "/var/www/dynamic-vhosts"
# (RSRC) DynVhosts_HostIPs          x.x.x.x [x.x.x.x [x.x.x.x]]
# (RSRC|HTACCESS) DynVhosts_DomainCatchAll   "__catchall__" # parallel to document root
# (RSRC|HTACCESS) DynVhosts_Logging          On|Off
# (RSRC|HTACCESS) DynVhosts_LoggingBase      "logs/dynamic-vhosts"
# (RSRC|HTACCESS) DynVhosts_LoggingSchedule  weekly
# (RSRC|HTACCESS) DynVhosts_LoggingMaxOpen   20
# (RSRC|HTACCESS) DynVhosts_LoggingMaxSize   100M
# (RSRC|HTACCESS) DynVhosts_GZipOnRotate     On|Off
# (RSRC|HTACCESS) DynVhosts_AutoFlush        On|Off

my @directives = (
    {
        name => 'DynVhosts_State',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::FLAG,
        errmsg => 'DynVhosts_State On|Off',
    },
    {
        name => 'DynVhosts_Base',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_Base <path>',
    },
    {
        name => 'DynVhosts_DocumentRoot',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_DocumentRoot <path-template>',
    },
    {
        name => 'DynVhosts_DomainList',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_DomainList <file|directory>',
    },
    {
        name => 'DynVhosts_HostIPs',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::ITERATE,
        errmsg => 'DynVhosts_HostIPs x.x.x.x [x.x.x.x [x.x.x.x [...]]]',
    },
    {
        name => 'DynVhosts_DomainCatchAll',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_DomainCatchAll <name of domain catchall directory>',
    },
    {
        name => 'DynVhosts_Logging',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::FLAG,
        errmsg => 'DynVhosts_Logging On|Off',
    },
    {
        name => 'DynVhosts_LoggingFormat',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_LoggingFormat "<format>"',
    },
    {
        name => 'DynVhosts_LoggingBase',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_LoggingBase <path>',
    },
    {
        name => 'DynVhosts_LoggingSchedule',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_LoggingSchedule <filesize|never|daily|weekly|monthly|yearly>',
    },
    {
        name => 'DynVhosts_LoggingMaxFileSize',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_LoggingMaxFileSize <maximum file size: \d+(K|M|G|T|P)',
    },
    {
        name => 'DynVhosts_LoggingMaxFilesOpen',
        req_override => Apache2::Const::RSRC_CONF,
        args_how => Apache2::Const::TAKE1,
        errmsg => 'DynVhosts_LoggingMaxFilesOpen <maximum number of files open at a time>',
    },
    {
        name => 'DynVhosts_GZipOnLogRotate',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::FLAG,
        errmsg => 'DynVhosts_GZipOnLogRotate On|Off',
    },
    {
        name => 'DynVhosts_LoggingAutoFlush',
        req_override => Apache2::Const::RSRC_CONF | Apache2::Const::OR_OPTIONS,
        args_how => Apache2::Const::FLAG,
        errmsg => 'DynVhosts_LoggingAutoFlush On|Off',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub DynVhosts_State          {
    my ($self, $parms, $arg) = @_;

    if ($arg == On) {
        foreach my $opt (keys %{$defaults}) {
            set_val($opt, ($self, $parms, $defaults->{$opt}));
        }
        set_val('state', ($self, $parms, On));
    }
    set_val('state', @_);
}

sub DynVhosts_DocumentRoot   { set_val('document_root', @_) }

sub DynVhosts_DomainList {
    my ($self, $parms, $arg) = @_;

    # validate that the arguments are strings
    unless (-f $arg || -d $arg) {
        my $directive = $parms->directive;
        die sprintf "error: DynVhosts_DomainList at %s:%d expects a valid file or directory argument: ('$arg' is not a valid file or directory)",
            $directive->filename(), $directive->line_num;
    }

    set_val('domain_list', @_);
}

# note: we don't do any merging of host_ips (see: SERVER/DIR_MERGE)
# because, 1. user's can't change them in htaccess files anyway,
# and 2. we wouldn't want them to if they could (or would we...?)
sub DynVhosts_HostIPs        { push_val('host_ips', @_) }

sub DynVhosts_DomainCatchAll { set_val('domain_catchall', @_) }
sub DynVhosts_Logging        { set_val('logging', @_) }
sub DynVhosts_LoggingFormat  { set_val('logging_format', @_) }
sub DynVhosts_LoggingBase    { set_val('logging_base', @_) }

sub DynVhosts_LoggingSchedule     {
    my ($self, $parms, $arg) = @_;
    my $directive = $parms->directive;
    unless (grep(/^$arg$/, qw(filesize never daily weekly monthly yearly))) {
        die sprintf "error: DynVhosts_LoggingSchedule at %s:%d expects one of 'filesize', 'never', 'daily', 'weekly', 'monthly' or 'yearly' - got: '$arg'",
            $directive->filename(), $directive->line_num;
    }

    $arg = $rotate_types{lc($arg)};
    set_val('logging_schedule', ($self, $parms, $arg))
}

sub DynVhosts_LoggingMaxFileSize  {
    my ($self, $parms, $arg) = @_;
    my $directive = $parms->directive;
    unless ($arg =~ /^(\d+)(B|K|M|G|T|P)?$/) {
        die sprintf "error: DynVhosts_LoggingMaxFileSize at %s:%d expects an integer value with size specifier (B, K, M, G, T or P) - got: '$arg'",
            $directive->filename(), $directive->line_num;
    }
    $arg = ($1 * (defined($2) && exists $byte_sizes{uc($2)} ? $byte_sizes{uc($2)} : 1));
    set_val('logging_max_file_size', ($self, $parms, $arg))
}

sub DynVhosts_LoggingMaxFilesOpen {
    my ($self, $parms, $arg) = @_;
    my $directive = $parms->directive;
    unless ($arg =~ /^\d+$/) {
        die sprintf "error: DynVhosts_LoggingMaxFilesOpen at %s:%d expects an integer value - got: '$arg'",
            $directive->filename(), $directive->line_num;
    }
    set_val('logging_max_files_open', @_)
}

sub DynVhosts_GZipOnLogRotate   { set_val('gzip_on_log_rotate', @_) }
sub DynVhosts_LoggingAutoFlush  { set_val('logging_autoflush', @_) }

sub DIR_MERGE    { merge(@_) }
sub SERVER_MERGE { merge(@_) }

sub set_val {
    my ($key, $self, $parms, $arg) = @_;
    $self->{$key} = $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
        $srv_cfg->{$key} = $arg;
    }
}

sub push_val {
    my ($key, $self, $parms, $arg) = @_;
    push @{ $self->{$key} }, $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
        push @{ $srv_cfg->{$key} }, $arg;
    }
}

sub merge {
    my ($base, $add) = @_;

    my %mrg = ();
    for my $key (keys %$base, keys %$add, keys %$defaults) {
        next if exists $mrg{$key};
        $mrg{$key} = $defaults->{$key} if exists $defaults->{$key};
        $mrg{$key} = $base->{$key} if exists $base->{$key};
        $mrg{$key} = $add->{$key}  if exists $add->{$key};
    }

    return bless \%mrg, ref($base);
}

1;
