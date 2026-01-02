#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use Milton::Interface::Utils::SCPIScanner;
use Milton::Config::Path qw(clear_search_path add_search_dir search_path);

clear_search_path();
add_search_dir('t');

subtest 'Constructor' => sub {
  my $scanner = Milton::Interface::Utils::SCPIScanner->new();
  isa_ok($scanner, 'Milton::Interface::Utils::SCPIScanner');

  my $devices = $scanner->{devices};
  my $serial = $devices->{serial};
  my $usbtmc = $devices->{usbtmc};
  my $rigol  = $devices->{rigol};

  is($serial->[0]
   , { displayName => 'Kiprim DC310S'
     , name => 'Kiprim DC310S'
     , description => 'Standard configuration for the Kiprim DC310S power supply.'
     , value => 'interface/kiprim/dc310s.yaml'
     , manufacturer => 'kiprim'
     , type => 'serial'
     , 'id-pattern-re' => $serial->[0]->{'id-pattern-re'}
     , document => { package => 'Milton::Interface::SCPI::Serial'
                   , 'id-pattern' => '^KIPRIM DC310S'
                   , baudrate => 115200
                   , device => '/dev/ttyUSB[0-9]*'
                   , 'shutdown-commands' => [ 'SYST:LOC' ]
                   , voltage => { maximum => 31.9, minimum => 2 }
                   , current => { maximum => 10.1, minimum => 0.5, measurable => 0.1 }
                   , power => { maximum => 299, minimum => 1 }
                   }
     }
     , 'Serial[0] - Kiprim DC310S'
     );

  is($usbtmc->[1]
   , { displayName => 'Siglent SPD1305X'
     , name => 'Siglent SPD1305X'
     , description => 'Standard configuration for the Siglent SPD1305X power supply.'
     , value => 'interface/siglent/spd1305x.yaml'
     , manufacturer => 'siglent'
     , type => 'usbtmc'
     , 'id-pattern-re' => $usbtmc->[1]->{'id-pattern-re'}
     , document => { package => 'Milton::Interface::SCPI::USBTMC'
                   , 'id-pattern' => '^Siglent .*SPD1305X'
                   , device => '/dev/usbtmc[0-9]*'
                   , 'shutdown-commands' => [ '*UNLOCK' ]
                   , voltage => { maximum => 30, minimum => 2 }
                   , current => { maximum => 5, minimum => 0.5, measurable => 0.1 }
                   , power => { maximum => 149.5, minimum => 1 }
                   }
     }
     , 'USBTMC[1] - Siglent SPD1305X'
     );

  is($rigol->[0]
   , { displayName => 'Rigol DP711'
     , name => 'Rigol DP711'
     , description => 'Standard configuration for the Rigol DP711 power supply.'
     , value => 'interface/rigol/dp711.yaml'
     , manufacturer => 'rigol'
     , type => 'serial'
     , 'id-pattern-re' => $rigol->[0]->{'id-pattern-re'}
     , document => { package => 'Milton::Interface::SCPI::Serial'
                   , 'id-pattern' => '^Rigol DP711'
                   , 'command-length' => 26
                   , baudrate => 9600
                   , device => '/dev/ttyS[0-9]*'
                   , 'shutdown-commands' => [ 'SYST:LOC' ]
                   , voltage => { maximum => 30, minimum => 2 }
                   , current => { maximum => 5, minimum => 0.5, measurable => 0.1 }
                   , power => { maximum => 149.5, minimum => 1 }
                   }
     }
     , 'Rigol[0] - Rigol DP711'
     );
};

1;