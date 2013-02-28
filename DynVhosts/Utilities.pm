package DynVhosts::Utilities;

use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);

use constant PATH_PREPEND => 1;
use constant PATH_APPEND  => 2;

our %EXPORT_TAGS = (
    'constants' => [
        qw(
            PATH_PREPEND
            PATH_APPEND
        )
    ],
    'env-path' => [
        qw(
            PATH_PREPEND
            PATH_APPEND
    
            add_env_path
            get_env_path
            del_env_path
        )
    ],
    'misc' => [
        qw(
            empty
            echo
            filter
            in_array
            repeat
            str_replace
            trim
            unique
        )
    ],
);

$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];

# XXX: use all for now. in the future, explicit exporting will be required
our @EXPORT = @{$EXPORT_TAGS{all}};

use DynVhosts::Constants;

sub empty {
    use Data::Dumper;
    return TRUE if (!defined(@_) || scalar(@_) == 0);
    return TRUE if (scalar(@_) == 1 && (!defined($_[0]) || $_[0] =~ m/^(\s*|0)$/));
    return TRUE if (ref($_[0]) eq 'ARRAY' && scalar(@{$_[0]}) == 0);
    return TRUE if (ref($_[0]) eq 'HASH' && scalar(keys %{$_[0]}) == 0);
    return FALSE;
}

sub echo { print @_; }

sub in_array($@) {
    my ($item, @array) = @_;
    return FALSE if (!defined($item) || empty($item));
    my %hash_map = map({ $_ => 1 } @array);
    return (exists($hash_map{$item}) ? TRUE : FALSE);
}

# repeat a string X times
sub repeat {
    my ($string, $repeat) = @_;
    my $result = '';
    for (my $i = 0; $i < $repeat; $i++) {
        $result .= $string;
    }
    return $result;
}

sub str_replace($$$) {
    my ($search, $replace, $string) = @_;
    $string =~ s/\Q$search\E/$replace/;
    return $string;
}

sub trim($) {
    my ($string) = @_;
    $string =~ s/^\s*(.*)\s*$/$1/g;
    return $string;
}

sub get_env_path() { return split(':', $ENV{PATH}); }

sub del_env_path($) {
    my ($path) = @_;
    
    if (!empty($path) && in_array($path, get_env_path())) {
        my %hash = map({ $_ => 1 } get_env_path());
        delete($hash{$path});
        $ENV{PATH} = join(':', keys %hash);
    }
    return TRUE;
}

sub add_env_path($;$) {
    my ($path, $where) = @_;
    
    return FALSE if (empty($path) || ! -d $path);
    $where = PATH_APPEND if (!defined($where) || empty($where));
    
    my @path = get_env_path();
    if (PATH_APPEND == $where) {
        push(@path, $path);
    } else {
        unshift(@path, $path);
    }
    
    $ENV{PATH} = join(':', @path);
    return TRUE;
}

sub unique(@) { return keys( %{ { map { $_ => 1 } @_ } }); }

sub filter {
    my (@array, $term) = @_;
    return grep { !empty($_) } @array if (!defined($term) || empty($term));
    return grep { !empty($_) && $_ =~ /\Q$term\E/ } @array;    
}

1;
