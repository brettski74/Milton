#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Controller::BangBang;
use PowerSupplyControl::t::MockInterface;

# Test basic constructor
note("Testing constructor");
my $config = {
    temperatures => [
        { resistance => 10.0, temperature => 20.0 },
        { resistance => 12.0, temperature => 100.0 }
    ]
};
my $interface = PowerSupplyControl::t::MockInterface->new();
my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);

isa_ok($controller, 'PowerSupplyControl::Controller::BangBang');
isa_ok($controller, 'PowerSupplyControl::Controller::RTDController');
isa_ok($controller, 'PowerSupplyControl::Controller');

# Test inheritance - should have RTD estimator
is($controller->estimatorLength(), 2, 'Should have 2 calibration points from config');

# Test bang-bang control logic
note("Testing bang-bang control logic");

# Set power limits for testing
my $MIN_POWER = 5.0;
my $MAX_POWER = 100.0;
$interface->{min_power} = $MIN_POWER;
$interface->{max_power} = $MAX_POWER;

# Test when temperature is below target (should return max power)
note("Testing temperature below target");
my $status = { temperature => 50.0 };
my $target_temp = 100.0;
my $power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return max power when temperature < target');

# Test when temperature equals target (should return min power)
note("Testing temperature equals target");
$status = { temperature => 100.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature = target');

# Test when temperature is above target (should return min power)
note("Testing temperature above target");
$status = { temperature => 150.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature > target');

# Test with different power limits
note("Testing different power limits");
$interface->{min_power} = $MIN_POWER = 10.0;
$interface->{max_power} = $MAX_POWER = 50.0;

$status = { temperature => 50.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return new max power when temperature < target');

$status = { temperature => 100.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return new min power when temperature >= target');

# Test edge cases
note("Testing edge cases");

# Test with very small temperature difference
$status = { temperature => 99.999 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return max power for temperature just below target');

$status = { temperature => 100.001 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power for temperature just above target');

# Test with negative temperatures
$status = { temperature => -50.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return max power for negative temperature below target');

# Test with very high temperatures
$status = { temperature => 500.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power for very high temperature above target');

# Test with zero target temperature
note("Testing zero target temperature");
$target_temp = 0.0;

$status = { temperature => -10.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return max power when temperature < 0 target');

$status = { temperature => 0.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature = 0 target');

$status = { temperature => 10.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature > 0 target');

# Test with negative target temperature
note("Testing negative target temperature");
$target_temp = -50.0;

$status = { temperature => -100.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MAX_POWER, 'Should return max power when temperature < negative target');

$status = { temperature => -50.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature = negative target');

$status = { temperature => 0.0 };
$power = $controller->getRequiredPower($status, $target_temp);
is($power, $MIN_POWER, 'Should return min power when temperature > negative target');

done_testing(); 