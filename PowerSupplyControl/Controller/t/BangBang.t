#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Controller::BangBang;
use PowerSupplyControl::t::MockInterface;
use Readonly;

Readonly my $EPS => 0.000001;

subtest 'Basic Bang-Bang' => sub {
  my $config = {};
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  isa_ok($controller, 'PowerSupplyControl::Controller::BangBang');
  isa_ok($controller, 'PowerSupplyControl::Controller::RTDController');
  isa_ok($controller, 'PowerSupplyControl::Controller');

  is($controller->getRequiredPower({ temperature => 25.0 }, 75.0), 100.0, '25.0 < 75.0');
  is($controller->getRequiredPower({ temperature => 74.999 }, 75.0), 100.0, '74.999 < 75.0');
  is($controller->getRequiredPower({ temperature => 75.0 }, 75.0), 2.0, '75.0 == 75.0');
  is($controller->getRequiredPower({ temperature => 80.0 }, 75.0), 2.0, '80.0 > 75.0');

  is($controller->getRequiredPower({ temperature => 25.0 }, 120.0), 100.0, '25.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999 }, 120.0), 100.0, '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0 }, 120.0), 2.0, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0 }, 120.0), 2.0, '125.0 > 120.0');
};

subtest 'Single-level Bang-Bang' => sub {
  my $config = { 'power-levels' => [ { temperature => 25.0
                                     , power => 83.2
                                     }
                                   ]
               };
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 25.0 }, 75.0), 83.2, '25.0 < 75.0');
  is($controller->getRequiredPower({ temperature => 74.999 }, 75.0), 83.2, '74.999 < 75.0');
  is($controller->getRequiredPower({ temperature => 75.0 }, 75.0), 2, '75.0 == 75.0');
  is($controller->getRequiredPower({ temperature => 80.0 }, 75.0), 2, '80.0 > 75.0');

  is($controller->getRequiredPower({ temperature => 25.0 }, 120.0), 83.2, '25.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999 }, 120.0), 83.2, '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0 }, 120.0), 2.0, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0 }, 120.0), 2.0, '125.0 > 120.0');
};

subtest 'Modulated Bang-Bang' => sub {
  my $config = { 'power-levels' => [ { temperature => 25.0
                                     , power => 20.0
                                     }
                                   , { temperature => 200.0
                                     , power => 100.0
                                     }
                                   ]
              };

  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 24.0 }, 25.0), 20, '24.0 < 25.0');
  is($controller->getRequiredPower({ temperature => 25.0 }, 25.0), 2, '25.0 == 25.0');
  is($controller->getRequiredPower({ temperature => 27.0 }, 25.0), 2, '27.0 > 25.0');

  is($controller->getRequiredPower({ temperature => 24.0 }, 200.0), 100, '24.0 < 200.0');
  is($controller->getRequiredPower({ temperature => 199.999 }, 200.0), 100, '199.999 < 200.0');
  is($controller->getRequiredPower({ temperature => 200.0 }, 200.0), 2, '200.0 == 200.0');
  is($controller->getRequiredPower({ temperature => 205.0 }, 200.0), 2, '205.0 > 200.0');

  is($controller->getRequiredPower({ temperature => 24.0 }, 120.0), float(444/7, tolerance => $EPS), '24.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999 }, 120.0), float(444/7, tolerance => $EPS), '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0 }, 120.0), 2, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0 }, 120.0), 2, '125.0 > 120.0');
};

done_testing(); 