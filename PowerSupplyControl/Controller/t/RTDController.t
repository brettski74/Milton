#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Controller::RTDController;
use PowerSupplyControl::t::MockInterface;

my $EPS = 0.0000001;

# Create a mock interface for testing
my $mock_interface = PowerSupplyControl::t::MockInterface->new;

# Test basic constructor with 2-point calibration
note("Testing RTDController constructor with 2-point calibration");
my $config = {
    temperatures => [
        { resistance => 1.0, temperature => 25.0 },
        { resistance => 2.0, temperature => 225.0 }
    ]
};

my $rtd_controller = PowerSupplyControl::Controller::RTDController->new($config, $mock_interface);
isa_ok($rtd_controller, 'PowerSupplyControl::Controller::RTDController');
isa_ok($rtd_controller, 'PowerSupplyControl::Controller');

# Test that the RT estimator was created
ok(exists $rtd_controller->{rt_estimator}, 'RT estimator should be created');
isa_ok($rtd_controller->{rt_estimator}, 'PowerSupplyControl::PiecewiseLinear');

# Test resistance to temperature conversion - exact points
note("Testing resistance to temperature conversion at calibration points");
my $sts = { voltage => 10.0, current => 10.0 };  # = 1 ohm
is($rtd_controller->getTemperature($sts), float(25.0, tolerance => $EPS), '1 ohm == 25 celsius');
is($sts->{resistance}, 1.0, 'resistance = 1.0');
is($sts->{temperature}, 25.0, 'temperature = 25.0');

my $sts2 = { voltage => 12.0, current => 6.0 };  # R = 2 ohms
is($rtd_controller->getTemperature($sts2), float(225.0, tolerance => $EPS), '2 ohm == 225 celsius');
is($sts2->{resistance}, 2.0, 'resistance = 2.0');
is($sts2->{temperature}, 225.0, 'temperature = 225.0');

# Test interpolation between calibration points
note("Testing interpolation between calibration points");
my $sts3 = { voltage => 10.5, current => 7.0 };  # R = 1.5 ohms
is($rtd_controller->getTemperature($sts3), float(125.0, tolerance => $EPS), '1.5 ohm == 125 celsius');
is($sts3->{resistance}, float(1.5, tolerance => $EPS), 'resistance = 1.5');
is($sts3->{temperature}, float(125.0, tolerance => $EPS), 'temperature = 125.0');

# Test extrapolation below range
note("Testing extrapolation below calibration range");
my $sts4 = { voltage => 9.5, current => 10.0 };  # R = 0.95 ohm
is($rtd_controller->getTemperature($sts4), float(15.0, tolerance => $EPS), '0.95 ohm == 15 celsius');
is($sts4->{resistance}, float(0.95, tolerance => $EPS), 'resistance = 0.95');
is($sts4->{temperature}, float(15.0, tolerance => $EPS), 'temperature = 15.0');

# Test extrapolation above range
note("Testing extrapolation above calibration range");
my $sts5 = { voltage => 15.0, current => 5.0 };  # R = 3 ohms
is($rtd_controller->getTemperature($sts5), float(425.0, tolerance => $EPS), '3 ohm == 425 celsius');
is($sts5->{resistance}, float(3.0, tolerance => $EPS), 'resistance = 3.0');
is($sts5->{temperature}, float(425.0, tolerance => $EPS), 'temperature = 425.0');

my $rtd_empty = PowerSupplyControl::Controller::RTDController->new({}, $mock_interface);
is($rtd_empty->getTemperature({ voltage => 12.0, current => 10.0 }), float(20.0, tolerance => $EPS), 'empty estimator cold');
is($rtd_empty->getTemperature({ voltage => 11.34, current => 7.0 }), float(109.0585242, tolerance => $EPS), 'empty estimator midpoint');
is($rtd_empty->getTemperature({ voltage => 12.24, current => 6.0 }), float(198.1170483, tolerance => $EPS), 'empty estimator hot');

my $rtd_one = PowerSupplyControl::Controller::RTDController->new({ temperatures => [ { resistance => 1.2, temperature => 25.0 } ] }, $mock_interface);
is($rtd_one->getTemperature({ voltage => 12.0, current => 10.0 }), float(25.0, tolerance => $EPS), 'one point estimator cold');
is($rtd_one->getTemperature({ voltage => 11.34, current => 7.0 }), float(115.8085242, tolerance => $EPS), 'one point estimator midpoint');
is($rtd_one->getTemperature({ voltage => 12.24, current => 6.0 }), float(206.6170483, tolerance => $EPS), 'one point estimator hot');

done_testing(); 