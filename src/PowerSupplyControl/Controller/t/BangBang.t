#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Controller::BangBang;
use PowerSupplyControl::t::MockInterface;
use Readonly;

Readonly my $EPS => 0.000001;

subtest 'Zero Hysteresis, Flat' => sub {
  my $config = { hysteresis => { low => 0, high => 0 } };
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  isa_ok($controller, 'PowerSupplyControl::Controller::BangBang');
  isa_ok($controller, 'PowerSupplyControl::Controller::RTDController');
  isa_ok($controller, 'PowerSupplyControl::Controller');

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 75.0 }), 100.0, '25.0 < 75.0');
  is($controller->getRequiredPower({ temperature => 74.999, 'then-temperature' => 75.0 }), 100.0, '74.999 < 75.0');
  is($controller->getRequiredPower({ temperature => 75.0, 'then-temperature' => 75.0 }), 2.0, '75.0 == 75.0');
  is($controller->getRequiredPower({ temperature => 80.0, 'then-temperature' => 75.0 }), 2.0, '80.0 > 75.0');

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 120.0 }), 100.0, '25.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999, 'then-temperature' => 120.0 }), 100.0, '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0, 'then-temperature' => 120.0 }), 2.0, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0, 'then-temperature' => 120.0 }), 2.0, '125.0 > 120.0');
};

subtest 'Single-level Bang-Bang' => sub {
  my $config = { 'power-levels' => [ { temperature => 25.0
                                     , power => 83.2
                                     }
                                   ]
               , hysteresis => { low => 0, high => 0 }
               };
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 75.0 }), 83.2, '25.0 < 75.0');
  is($controller->getRequiredPower({ temperature => 74.999, 'then-temperature' => 75.0 }), 83.2, '74.999 < 75.0');
  is($controller->getRequiredPower({ temperature => 75.0, 'then-temperature' => 75.0 }), 2, '75.0 == 75.0');
  is($controller->getRequiredPower({ temperature => 80.0, 'then-temperature' => 75.0 }), 2, '80.0 > 75.0');

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 120.0 }), 83.2, '25.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999, 'then-temperature' => 120.0 }), 83.2, '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0, 'then-temperature' => 120.0 }), 2.0, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0, 'then-temperature' => 120.0 }), 2.0, '125.0 > 120.0');
};

subtest 'Modulated Bang-Bang, Zero Hysteresis' => sub {
  my $config = { 'power-levels' => [ { temperature => 25.0
                                     , power => 20.0
                                     }
                                   , { temperature => 200.0
                                     , power => 100.0
                                     }
                                   ]
              , hysteresis => { low => 0, high => 0 }
              };

  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 24.0, 'then-temperature' => 25.0 }), 20, '24.0 < 25.0');
  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 25.0 }), 2, '25.0 == 25.0');
  is($controller->getRequiredPower({ temperature => 27.0, 'then-temperature' => 25.0 }), 2, '27.0 > 25.0');

  is($controller->getRequiredPower({ temperature => 24.0, 'then-temperature' => 200.0 }), 100, '24.0 < 200.0');
  is($controller->getRequiredPower({ temperature => 199.999, 'then-temperature' => 200.0 }), 100, '199.999 < 200.0');
  is($controller->getRequiredPower({ temperature => 200.0, 'then-temperature' => 200.0 }), 2, '200.0 == 200.0');
  is($controller->getRequiredPower({ temperature => 205.0, 'then-temperature' => 200.0 }), 2, '205.0 > 200.0');

  is($controller->getRequiredPower({ temperature => 24.0, 'then-temperature' => 120.0 }), float(444/7, tolerance => $EPS), '24.0 < 120.0');
  is($controller->getRequiredPower({ temperature => 119.999, 'then-temperature' => 120.0 }), float(444/7, tolerance => $EPS), '119.999 < 120.0');
  is($controller->getRequiredPower({ temperature => 120.0, 'then-temperature' => 120.0 }), 2, '120.0 == 120.0');
  is($controller->getRequiredPower({ temperature => 125.0, 'then-temperature' => 120.0 }), 2, '125.0 > 120.0');
};

subtest 'Flat with Hysteresis' => sub {
  my $config = { hysteresis => { low => 3, high => 3 } };
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 75.0 }), 100.0, '25.0 < 75.0 + 3');
  is($controller->getRequiredPower({ temperature => 74.9, 'then-temperature' => 75.0 }), 100.0, '74.9 < 75.0 + 3');
  is($controller->getRequiredPower({ temperature => 75.0, 'then-temperature' => 75.0 }), 100.0, '75.0 < 75.0 + 3');
  is($controller->getRequiredPower({ temperature => 77.9, 'then-temperature' => 75.0 }), 100.0, '77.9 < 75.0 + 3');
  is($controller->getRequiredPower({ temperature => 78.0, 'then-temperature' => 75.0 }), 2.0, '78.0 == 75.0 + 3');
  is($controller->getRequiredPower({ temperature => 78.1, 'then-temperature' => 75.0 }), 2.0, '78.1 > 75.0 + 3');

  is($controller->getRequiredPower({ temperature => 78.0, 'then-temperature' => 75.0 }), 2.0, '78.0 > 75.0 - 3');
  is($controller->getRequiredPower({ temperature => 75.0, 'then-temperature' => 75.0 }), 2.0, '75.0 > 75.0 - 3');
  is($controller->getRequiredPower({ temperature => 72.1, 'then-temperature' => 75.0 }), 2.0, '72.1 > 75.0 - 3');
  is($controller->getRequiredPower({ temperature => 72.0, 'then-temperature' => 75.0 }), 2.0, '72.0 == 75.0 - 3');
  is($controller->getRequiredPower({ temperature => 71.9, 'then-temperature' => 75.0 }), 100.0, '71.9 < 75.0 - 3');

  $config = { hysteresis => { low => -3, high => 2 } };
  $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 65.0 }), 100.0, '25.0 < 65.0 + 2');
  is($controller->getRequiredPower({ temperature => 64.9, 'then-temperature' => 65.0 }), 100.0, '64.9 < 65.0 + 2');
  is($controller->getRequiredPower({ temperature => 65.0, 'then-temperature' => 65.0 }), 100.0, '65.0 < 65.0 + 2');
  is($controller->getRequiredPower({ temperature => 66.9, 'then-temperature' => 65.0 }), 100.0, '66.9 < 65.0 + 2');
  is($controller->getRequiredPower({ temperature => 67.0, 'then-temperature' => 65.0 }), 2.0, '67.0 == 65.0 + 2');
  is($controller->getRequiredPower({ temperature => 67.1, 'then-temperature' => 65.0 }), 2.0, '67.1 > 65.0 + 2');

  is($controller->getRequiredPower({ temperature => 66.0, 'then-temperature' => 65.0 }), 2.0, '66.0 > 65.0');
  is($controller->getRequiredPower({ temperature => 65.1, 'then-temperature' => 65.0 }), 2.0, '65.1 > 65.0');
  is($controller->getRequiredPower({ temperature => 65.0, 'then-temperature' => 65.0 }), 2.0, '65.0 == 65.0');
  is($controller->getRequiredPower({ temperature => 64.9, 'then-temperature' => 65.0 }), 100.0, '64.9 < 65.0');
  is($controller->getRequiredPower({ temperature => 62.0, 'then-temperature' => 65.0 }), 100.0, '62.0 < 65.0');

  $config = { hysteresis => { low => 1, high => -2 } };
  $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  is($controller->getRequiredPower({ temperature => 25.0, 'then-temperature' => 67.0 }), 100.0, '25.0 < 67.0');
  is($controller->getRequiredPower({ temperature => 66.9, 'then-temperature' => 67.0 }), 100.0, '66.9 < 67.0');
  is($controller->getRequiredPower({ temperature => 67.0, 'then-temperature' => 67.0 }), 2.0, '67.0 == 67.0');
  is($controller->getRequiredPower({ temperature => 67.1, 'then-temperature' => 67.0 }), 2.0, '67.1 > 67.0');

  is($controller->getRequiredPower({ temperature => 67.0, 'then-temperature' => 67.0 }), 2.0, '67.0 > 67.0 - 1');
  is($controller->getRequiredPower({ temperature => 66.1, 'then-temperature' => 67.0 }), 2.0, '66.1 > 67.0 - 1');
  is($controller->getRequiredPower({ temperature => 66.0, 'then-temperature' => 67.0 }), 2.0, '66.0 == 67.0 - 1');
  is($controller->getRequiredPower({ temperature => 65.9, 'then-temperature' => 67.0 }), 100.0, '65.9 < 67.0 - 1');
  is($controller->getRequiredPower({ temperature => 62.0, 'then-temperature' => 67.0 }), 100.0, '62.0 < 67.0 - 1');

};

subtest 'Cut-off Temperature' => sub {
  my $config = { 'cut-off-temperature' => 225
               , hysteresis => { low => 0, high => 0 }
               , predictor => { package => 'PowerSupplyControl::Predictor::LowPassFilter'
                             , tau => 28
                             }
               };
  my $interface = PowerSupplyControl::t::MockInterface->new();
  $interface->setPowerLimits(2, 100);
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

  $controller->setPredictedTemperature(210);

  my $status = { period => 1.5, temperature => 222, 'then-temperature' => 215.0 };
  is($controller->getRequiredPower($status), 100.0, 'Still below cut-off');
  is ($status->{'predict-temperature'}, float(210.6101695, tolerance => 0.0001), 'predict-temperature');
  $status->{temperature} = 224.9;
  is($controller->getRequiredPower($status), 100.0, 'Just below cut-off');
  is ($status->{'predict-temperature'}, float(211.336771, tolerance => 0.0001), 'predict-temperature');
  $status->{temperature} = 225;
  is($controller->getRequiredPower($status), 2.0, 'At cut-off');
  is ($status->{'predict-temperature'}, float(212.0315115, tolerance => 0.0001), 'predict-temperature');
  $status->{temperature} = 224.9;
  is($controller->getRequiredPower($status), 100.0, 'Back below cut-off');
  is ($status->{'predict-temperature'}, float(212.6858414, tolerance => 0.0001), 'predict-temperature');
  $status->{temperature} = 225.1;
  is($controller->getRequiredPower($status), 2.0, 'Above cut-off');
  is ($status->{'predict-temperature'}, float(213.3170698, tolerance => 0.0001), 'predict-temperature');

};

done_testing(); 