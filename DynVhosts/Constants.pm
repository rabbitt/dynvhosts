package DynVhosts::Constants;

use strict;
use warnings;

use base 'Exporter';
our @ISA = qw(Exporter);

my %constants = ();

# Boolean Constants
$constants{'FALSE'} = 0;
$constants{'False'} = 0;
$constants{'false'} = 0;
$constants{'TRUE'}  = 1;
$constants{'True'}  = 1;
$constants{'true'}  = 1;

$constants{'ON'} = $constants{'On'} = $constants{'on'} = $constants{'TRUE'};
$constants{'OFF'} = $constants{'Off'} = $constants{'off'} = $constants{'FALSE'};

# byte count constants
$constants{'BYTE'}     = (1);
$constants{'KILOBYTE'} = (1024**1);
$constants{'MEGABYTE'} = (1024**2);
$constants{'GIGABYTE'} = (1024**3);
$constants{'TERABYTE'} = (1024**4);
$constants{'PETABYTE'} = (1024**5);

# logging mode (access or error log)
$constants{'MODE_ACCESS'}    = 'access';
$constants{'MODE_ERROR'}     = 'error';

# rotation schedules
$constants{'ROTATE_NEVER'}   = 0;
$constants{'ROTATE_ONSIZE'}  = 1;
$constants{'ROTATE_DAILY'}   = 2;
$constants{'ROTATE_WEEKLY'}  = 3;
$constants{'ROTATE_MONTHLY'} = 4;
$constants{'ROTATE_YEARLY'}  = 5;

our %byte_sizes = (
    'B' => $constants{'BYTE'},
    'K' => $constants{'KILOBYTE'},
    'M' => $constants{'MEGABYTE'},
    'G' => $constants{'GIGABYTE'},
    'T' => $constants{'TERABYTE'},
    'P' => $constants{'PETABYTE'},
);

our @valid_byte_sizes = sort { $byte_sizes{$a} <=> $byte_sizes{$b} } keys %byte_sizes;

our %rotate_types = (
    'filesize'   => $constants{'ROTATE_ONSIZE'},
    'never'      => $constants{'ROTATE_NEVER'},
    'daily'      => $constants{'ROTATE_DAILY'},
    'weekly'     => $constants{'ROTATE_WEEKLY'},
    'monthly'    => $constants{'ROTATE_MONTHLY'},
    'yearly'     => $constants{'ROTATE_YEARLY'},
);

our @valid_rotations = sort { $rotate_types{$a} <=> $rotate_types{$b} } keys(%rotate_types);

our %rotate_templates = (
    $constants{'ROTATE_ONSIZE'}  => 'filesize-%Y%m%d.%T', # filesize-20090128.15:50:32
    $constants{'ROTATE_DAILY'}   => 'daily-%Y%m%d',       # daily-20090128
    $constants{'ROTATE_WEEKLY'}  => 'weekly-%U.%Y',       # weekly-4.2009
    $constants{'ROTATE_MONTHLY'} => 'monthly-%h.%Y',      # monthly-Jan.2009
    $constants{'ROTATE_YEARLY'}  => 'yearly-%Y',          # yearly-2009
);

our @EXPORT = (keys %constants, qw(@valid_rotations %rotate_types %rotate_templates %byte_sizes @valid_byte_sizes));

# use constant \%constants;

# setup each constant
eval "use constant '$_' => '$constants{$_}';" for (keys %constants);

1;
