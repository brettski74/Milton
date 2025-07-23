#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Command::power;
use PowerSupplyControl::t::MockController;
use PowerSupplyControl::t::MockInterface;

subtest '--run switch' => sub {
  my $config = { 'steady-state' => { samples => 20
                                   , threshold => 0.0001
                                   , smoothing => 0.9
                                   , reset => 0.001
                                   }
               };

  my $controller = PowerSupplyControl::t::MockController->new();
  my $interface = PowerSupplyControl::t::MockInterface->new();
  my $command = PowerSupplyControl::Command::power->new($config, $interface, $controller, 5, '--run');

  is($command->{run}, 1, 'run is true');
  is($command->{detector}, undef, 'detector is undef');

  $command = PowerSupplyControl::Command::power->new($config, $interface, $controller, '--run', 5);

  is($command->{run}, 1, 'run is true');
  is($command->{detector}, undef, 'detector is undef');
};

done_testing();