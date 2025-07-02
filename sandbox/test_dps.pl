#!/usr/bin/perl

use lib '.';
use HP::Interface::DPS;

my $dps = HP::Interface::DPS->new({ baudrate => 19200
                                  , address => 1
                                  , parity => 'none'
                                  });

my $data = $dps->poll();

print "$data\n";

