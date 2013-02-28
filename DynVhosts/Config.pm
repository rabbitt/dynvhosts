package DynVhosts::Config;

use strict;
use warnings;

my $instance = undef;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %options = @_;

    if (!defined($instance)) {

        my %defaults = (
            state             => 1,
            base              => '/var/www/dynamic-vhosts',
            document_root     => '{{domain}}/{{subpart-all}}/htdocs',
            domain_list       => '/var/www/dynamic-vhosts',
            domain_catchall   => '__catchall__',
            error_catchall    => '__error__',

            logging                => 1,
            logging_base           => 'logs/dynamic-vhosts',
            logging_schedule       => 'weekly',
            logging_max_files_open => 100,
            logging_max_file_size  => undef,
            logging_gzip_on_rotate => 1,
        );

        $instance = bless { conf => \%defaults }, $class;
    }

    if (keys %options) {
        $instance->set($_, $options{$_}) foreach (keys %options);
    }

    return $instance;
}

sub get($$) {
    my ($self, $option) = @_;
    return $self->{'conf'}{$option} || undef;
}

sub set($$$) {
    my ($self, $option, $value) = @_;

    my $old_value = undef;
    if (defined($instance->{'conf'})) {
        $old_value = $self->get($option);
        $self->{'conf'}{$option} = $value;
    }
    return $old_value;
}

1;
