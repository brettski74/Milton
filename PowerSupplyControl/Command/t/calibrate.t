#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Command::calibrate;
use PowerSupplyControl::t::MockInterface;
use PowerSupplyControl::t::MockController;

subtest '_nextStep method' => sub {
  my $interface = PowerSupplyControl::t::MockInterface->new;
  my $controller = PowerSupplyControl::t::MockController->new;
  my $config = {};

  note('Testing command defaults');
  my $command = PowerSupplyControl::Command::calibrate->new($config, $interface, $controller);

  is ($command->{step}, 0, 'step number');
  is($command->{power}, 10, 'step 0 power');
  is($command->{'step-end'}, 450, 'step 0 end');
  is($command->{'step-name'}, 'rising-10', 'step 0 name');

  $command->_nextStep;

  is ($command->{step}, 1, 'step number');
  is($command->{power}, 20, 'step 1 power');
  is($command->{'step-end'}, 900, 'step 1 end');
  is($command->{'step-name'}, 'rising-20', 'step 1 name');

  $command->_nextStep;

  is ($command->{step}, 2, 'step number');
  is($command->{power}, 10, 'step 2 power');
  is($command->{'step-end'}, 1350, 'step 2 end');
  is($command->{'step-name'}, 'falling-10', 'step 2 name');

  $command->_nextStep;

  is ($command->{step}, 3, 'step number');
  is($command->{power}, 30, 'step 3 power');
  is($command->{'step-end'}, 1800, 'step 3 end');
  is($command->{'step-name'}, 'rising-30', 'step 3 name');

  $command->_nextStep;

  is ($command->{step}, 4, 'step number');
  is($command->{power}, 20, 'step 4 power');
  is($command->{'step-end'}, 2250, 'step 4 end');
  is($command->{'step-name'}, 'falling-20', 'step 4 name');

  $command->_nextStep;

  is ($command->{step}, 5, 'step number');
  is($command->{power}, 40, 'step 5 power');
  is($command->{'step-end'}, 2700, 'step 5 end');
  is($command->{'step-name'}, 'rising-40', 'step 5 name');
  
  $command->_nextStep;

  is ($command->{step}, 6, 'step number');
  is($command->{power}, 30, 'step 6 power');
  is($command->{'step-end'}, 3150, 'step 6 end');
  is($command->{'step-name'}, 'falling-30', 'step 6 name');
  
  note('Testing with power-step=10 and step-duration=300');
   $config = { 'power-step' => 7.5
             , 'step-duration' => 300
             , 'maximum-temperature' => 250
             };

  $command = PowerSupplyControl::Command::calibrate->new($config, $interface, $controller);

  is ($command->{step}, 0, 'step number');
  is($command->{power}, 7.5, 'step 0 power');
  is($command->{'step-end'}, 300, 'step 0 end');
  is($command->{'step-name'}, 'rising-7.5', 'step 0 name');

  $command->_nextStep;

  is ($command->{step}, 1, 'step number');
  is($command->{power}, 15, 'step 1 power');
  is($command->{'step-end'}, 600, 'step 1 end');
  is($command->{'step-name'}, 'rising-15', 'step 1 name');

  $command->_nextStep;

  is ($command->{step}, 2, 'step number');
  is($command->{power}, 7.5, 'step 2 power');
  is($command->{'step-end'}, 900, 'step 2 end');
  is($command->{'step-name'}, 'falling-7.5', 'step 2 name');

  $command->_nextStep;

  is ($command->{step}, 3, 'step number');
  is($command->{power}, 22.5, 'step 3 power');
  is($command->{'step-end'}, 1200, 'step 3 end');
  is($command->{'step-name'}, 'rising-22.5', 'step 3 name');
  
  $command->_nextStep;

  is ($command->{step}, 4, 'step number');
  is($command->{power}, 15, 'step 4 power');
  is($command->{'step-end'}, 1500, 'step 4 end');
  is($command->{'step-name'}, 'falling-15', 'step 4 name');

  $command->_nextStep;

  is ($command->{step}, 5, 'step number');
  is($command->{power}, 30, 'step 5 power');
  is($command->{'step-end'}, 1800, 'step 5 end');
  is($command->{'step-name'}, 'rising-30', 'step 5 name');
  
  $command->_nextStep;

  is ($command->{step}, 6, 'step number');
  is($command->{power}, 22.5, 'step 6 power');
  is($command->{'step-end'}, 2100, 'step 6 end');
  is($command->{'step-name'}, 'falling-22.5', 'step 6 name');
  
};

done_testing;