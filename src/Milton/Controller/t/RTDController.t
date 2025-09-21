#!/usr/bin/perl

use lib '.';
use Test2::V0;
use Milton::Controller::RTDController;
use Milton::t::MockInterface;

my $EPS = 0.0000001;

# Create a mock interface for testing
my $interface = Milton::t::MockInterface->new;

# Test basic constructor with 2-point calibration
subtest 'constructor with 2-point calibration' => sub {
  note("Testing RTDController constructor with 2-point calibration");
  my $config = { 'maximum-temperature-rate' => 350
               ,  calibration => { temperatures => [ { resistance => 1.0, temperature => 25.0 }
                                                   , { resistance => 2.0, temperature => 225.0 }
                                                   ]
                                 }
               };

  my $rtd_controller = Milton::Controller::RTDController->new($config, $interface);
  isa_ok($rtd_controller, 'Milton::Controller::RTDController');
  isa_ok($rtd_controller, 'Milton::Controller');

  # Test that the RT estimator was created
  ok(exists $rtd_controller->{rt_estimator}, 'RT estimator should be created');
  isa_ok($rtd_controller->{rt_estimator}, 'Milton::Math::PiecewiseLinear');

  # Test resistance to temperature conversion - exact points
  note("Testing resistance to temperature conversion at calibration points");
  my $sts = { voltage => 10.0, current => 10.0, period => 1.5 };  # = 1 ohm
  is($rtd_controller->getTemperature($sts), float(25.0, tolerance => $EPS), '1 ohm == 25 celsius');
  is($sts->{resistance}, 1.0, 'resistance = 1.0');
  is($sts->{temperature}, 25.0, 'temperature = 25.0');

  my $sts2 = { voltage => 12.0, current => 6.0, period => 1.5 };  # R = 2 ohms
  is($rtd_controller->getTemperature($sts2), float(225.0, tolerance => $EPS), '2 ohm == 225 celsius');
  is($sts2->{resistance}, 2.0, 'resistance = 2.0');
  is($sts2->{temperature}, 225.0, 'temperature = 225.0');

  # Test interpolation between calibration points
  note("Testing interpolation between calibration points");
  my $sts3 = { voltage => 10.5, current => 7.0, period => 1.5 };  # R = 1.5 ohms
  is($rtd_controller->getTemperature($sts3), float(125.0, tolerance => $EPS), '1.5 ohm == 125 celsius');
  is($sts3->{resistance}, float(1.5, tolerance => $EPS), 'resistance = 1.5');
  is($sts3->{temperature}, float(125.0, tolerance => $EPS), 'temperature = 125.0');

  # Test extrapolation below range
  note("Testing extrapolation below calibration range");
  my $sts4 = { voltage => 9.5, current => 10.0, period => 1.5 };  # R = 0.95 ohm
  is($rtd_controller->getTemperature($sts4), float(15.0, tolerance => $EPS), '0.95 ohm == 15 celsius');
  is($sts4->{resistance}, float(0.95, tolerance => $EPS), 'resistance = 0.95');
  is($sts4->{temperature}, float(15.0, tolerance => $EPS), 'temperature = 15.0');

  # Test extrapolation above range
  note("Testing extrapolation above calibration range");
  my $sts5 = { voltage => 15.0, current => 5.0, period => 1.5 };  # R = 3 ohms
  is($rtd_controller->getTemperature($sts5), float(425.0, tolerance => $EPS), '3 ohm == 425 celsius');
  is($sts5->{resistance}, float(3.0, tolerance => $EPS), 'resistance = 3.0');
  is($sts5->{temperature}, float(425.0, tolerance => $EPS), 'temperature = 425.0');
};

subtest 'empty estimator' => sub {
  my $rtd_empty = Milton::Controller::RTDController->new({ 'maximum-temperature-rate' => 150 }, $interface);
  is($rtd_empty->getTemperature({ voltage => 12.0, current => 10.0, period => 1.5 }), float(25.0, tolerance => $EPS), 'empty estimator cold');
  is($rtd_empty->getTemperature({ voltage => 11.34, current => 7.0, period => 1.5 }), float(115.8085242, tolerance => $EPS), 'empty estimator midpoint');
  is($rtd_empty->getTemperature({ voltage => 12.24, current => 6.0, period => 1.5 }), float(206.6170483, tolerance => $EPS), 'empty estimator hot');
};

subtest 'one point estimator' => sub {
  my $config = { 'maximum-temperature-rate' => 150
               , calibration => { temperatures => [ { resistance => 1.2, temperature => 25.0 } ] }
               };
  my $rtd_one = Milton::Controller::RTDController->new($config, $interface);
  is($rtd_one->getTemperature({ voltage => 12.0, current => 10.0, period => 1.5 }), float(25.0, tolerance => $EPS), 'one point estimator cold');
  is($rtd_one->getTemperature({ voltage => 11.34, current => 7.0, period => 1.5 }), float(115.8085242, tolerance => $EPS), 'one point estimator midpoint');
  is($rtd_one->getTemperature({ voltage => 12.24, current => 6.0, period => 1.5 }), float(206.6170483, tolerance => $EPS), 'one point estimator hot');
};

done_testing(); 
