use strict;
use warnings;

use Test2::V0;
use lib '.';

use HP::SteadyStateDetector;

# Test construction with default parameters
subtest 'construction with defaults' => sub {
    my $detector = HP::SteadyStateDetector->new();
    
    my $params = $detector->getParameters();
    is($params->{smoothing}, 0.9, 'default smoothing is 0.9');
    is($params->{threshold}, 0.0001, 'default threshold is 0.0001');
    is($params->{samples}, 10, 'default samples is 10');
    is($params->{reset}, 0.00015, 'default reset is 1.5 * threshold');
    
    my $state = $detector->getState();
    is($state->{filtered_delta}, undef, 'initial filtered_delta is undef');
    is($state->{count}, 0, 'initial count is 0');
    is($state->{previous_measurement}, undef, 'initial previous_measurement is undef');
    is($state->{last_delta}, undef, 'initial last_delta is undef');
};

# Test construction with custom parameters
subtest 'construction with custom parameters' => sub {
    my $detector = HP::SteadyStateDetector->new(
        smoothing => 0.8,
        threshold => 0.001,
        samples => 5,
        reset => 0.002
    );
    
    my $params = $detector->getParameters();
    is($params->{smoothing}, 0.8, 'custom smoothing is set');
    is($params->{threshold}, 0.001, 'custom threshold is set');
    is($params->{samples}, 5, 'custom samples is set');
    is($params->{reset}, 0.002, 'custom reset is set');
};

subtest 'construction with incomplete parameters' => sub {
    my $detector = HP::SteadyStateDetector->new(
        smoothing => 0.85,
        threshold => 0.01,
        samples => 7,
    );

    my $params = $detector->getParameters();
    is($params->{smoothing}, 0.85, 'custom smoothing is set');
    is($params->{threshold}, 0.01, 'custom threshold is set');
    is($params->{samples}, 7, 'custom samples is set');
    is($params->{reset}, 0.015, 'default reset is 1.5 * threshold');

    $detector = HP::SteadyStateDetector->new(
        smoothing => 0.86,
        threshold => 0.02,
        samples => 8,
        reset => undef
    );

    $params = $detector->getParameters();
    is($params->{smoothing}, 0.86, 'custom smoothing is set');
    is($params->{threshold}, 0.02, 'custom threshold is set');
    is($params->{samples}, 8, 'custom samples is set');
    is($params->{reset}, 0.03, 'default reset is 1.5 * threshold');
};

# Test parameter validation
subtest 'parameter validation' => sub {
    # Test invalid smoothing
    ok(dies { HP::SteadyStateDetector->new(smoothing => 0) }, 'dies with zero smoothing');
    ok(dies { HP::SteadyStateDetector->new(smoothing => 1) }, 'dies with smoothing = 1');
    ok(dies { HP::SteadyStateDetector->new(smoothing => -0.1) }, 'dies with negative smoothing');
    ok(dies { HP::SteadyStateDetector->new(smoothing => 1.1) }, 'dies with smoothing > 1');
    
    # Test invalid threshold
    ok(dies { HP::SteadyStateDetector->new(threshold => 0) }, 'dies with zero threshold');
    ok(dies { HP::SteadyStateDetector->new(threshold => -0.1) }, 'dies with negative threshold');
    
    # Test invalid samples
    ok(dies { HP::SteadyStateDetector->new(samples => 0) }, 'dies with zero samples');
    ok(dies { HP::SteadyStateDetector->new(samples => -1) }, 'dies with negative samples');
    
    # Test invalid reset
    ok(dies { HP::SteadyStateDetector->new(threshold => 0.001, reset => 0.0005) }, 'dies with reset <= threshold');
};

# Test first measurement handling
subtest 'first measurement handling' => sub {
    my $detector = HP::SteadyStateDetector->new(smoothing => 0.5, threshold => 1.0, samples => 1);
    
    # First call should just store the measurement and return false
    my $result = $detector->check(10.0);
    is($result, 0, 'first measurement returns false');
    
    my $state = $detector->getState();
    is($state->{previous_measurement}, 10.0, 'first measurement is stored');
    is($state->{filtered_delta}, undef, 'filtered_delta still undef after first measurement');
    is($state->{count}, 0, 'count still 0 after first measurement');
};

# Test IIR filtering
subtest 'IIR filtering' => sub {
    my $detector = HP::SteadyStateDetector->new(smoothing => 0.5, threshold => 1.0, samples => 1);
    
    # First call should just store the measurement
    $detector->check(10.0);
    
    # Second call should initialize filtered_delta
    my $result = $detector->check(11.0);
    my $state = $detector->getState();
    is($state->{filtered_delta}, 1.0, 'second call initializes filtered_delta to delta');
    is($state->{last_delta}, 1.0, 'last_delta is set correctly');
    is($state->{previous_measurement}, 11.0, 'previous_measurement is updated');
    
    # Third call should apply IIR filter
    $result = $detector->check(12.0);
    $state = $detector->getState();
    is($state->{filtered_delta}, 1.0, 'IIR filter maintains value with constant delta');
    is($state->{last_delta}, 1.0, 'last_delta is updated');
    
    # Test with changing delta
    $result = $detector->check(13.5);
    $state = $detector->getState();
    is($state->{filtered_delta}, 1.25, 'IIR filter averages with new delta');
};

# Test steady state detection
subtest 'steady state detection' => sub {
    my $detector = HP::SteadyStateDetector->new(
        smoothing => 0.6,
        threshold => 0.1,
        samples => 3,
        reset => 0.2
    );
    
    # First measurement
    ok(!$detector->check(10.0), 'not steady yet');
    
    # Start with large changes (not steady)
    ok(!$detector->check(11.0), 'large change is not steady');
    ok(!$detector->check(12.0), 'large change is not steady');
    ok(!$detector->check(13.0), 'large change is not steady');
    
    my $state = $detector->getState();
    is($state->{count}, 0, 'count remains 0 with large changes');

    ok(!$detector->check(13.05), "small change, but insufficient history for steady state");
    ok(!$detector->check(13.08), "small change, but insufficient history for steady state");
    ok(!$detector->check(13.09), "small change, but insufficient history for steady state");
    ok(!$detector->check(13.09), "small change, but insufficient history for steady state");
    
    $state = $detector->getState();
    is($state->{count}, 0, 'count remains 0 with insufficient small change history');

    ok(!$detector->check(13.08), 'small change, but insufficient history for steady state');
    ok(!$detector->check(13.08), 'small change, but insufficient history for steady state');

    $state = $detector->getState();
    is($state->{count}, 2, 'count incremented as threshold was crossed.');
    ok(!$detector->isSteady(), 'not steady yet');

    ok($detector->check(13.09), 'steady state detected');
    $state = $detector->getState();
    is($state->{count}, 3, 'count incremented to reach steady state criteria.');
    ok($detector->isSteady(), 'now steady');

    ok($detector->check(13.5), 'larger change, but reset threshold not crossed');
    $state = $detector->getState();
    is($state->{count}, 4, 'count incremented to 4');
    ok($detector->isSteady(), 'still steady');

    ok(!$detector->check(13.73), 'moderate change, reset threshold crossed');
    $state = $detector->getState();
    is($state->{count}, 0, 'count reset to 0');
    ok(!$detector->isSteady(), 'not steady any more');

};

# Test reset method
subtest 'reset method' => sub {
    my $detector = HP::SteadyStateDetector->new(smoothing => 0.6, threshold => 0.1, samples => 3, reset => 0.2);
    
    # Build up some state
    $detector->check(10.0);
    $detector->check(10.05);
    $detector->check(10.05);
    $detector->check(10.05);
    $detector->check(10.05);
    $detector->check(10.05);
    
    my $state = $detector->getState();
    isnt($state->{filtered_delta}, undef, 'filtered_delta is set');
    is($state->{count}, number_gt(0), 'count is >0');
    isnt($state->{previous_measurement}, undef, 'previous_measurement is set');
    
    # Reset
    $detector->reset();
    $state = $detector->getState();
    is($state->{filtered_delta}, undef, 'filtered_delta is reset to undef');
    is($state->{count}, 0, 'count is reset to 0');
    is($state->{previous_measurement}, undef, 'previous_measurement is reset to undef');
    is($state->{last_delta}, undef, 'last_delta is reset to undef');
};

# Test edge cases
subtest 'negative deltas' => sub {
    my $detector = HP::SteadyStateDetector->new(
        smoothing => 0.6,
        threshold => 0.1,
        samples => 3,
        reset => 0.2
    );
    
    # First measurement
    ok(!$detector->check(10.0), 'not steady yet');
    
    # Start with large changes (not steady)
    ok(!$detector->check(9.0), 'large change is not steady');
    ok(!$detector->check(8.0), 'large change is not steady');
    ok(!$detector->check(7.0), 'large change is not steady');
    
    my $state = $detector->getState();
    is($state->{count}, 0, 'count remains 0 with large changes');

    ok(!$detector->check(6.95), "small change, but insufficient history for steady state");
    ok(!$detector->check(6.92), "small change, but insufficient history for steady state");
    ok(!$detector->check(6.91), "small change, but insufficient history for steady state");
    ok(!$detector->check(6.91), "small change, but insufficient history for steady state");
    
    $state = $detector->getState();
    is($state->{count}, 0, 'count remains 0 with insufficient small change history');

    ok(!$detector->check(6.92), 'small change, but insufficient history for steady state');
    ok(!$detector->check(6.92), 'small change, but insufficient history for steady state');

    $state = $detector->getState();
    is($state->{count}, 2, 'count incremented as threshold was crossed.');
    ok(!$detector->isSteady(), 'not steady yet');

    ok($detector->check(6.91), 'steady state detected');
    $state = $detector->getState();
    is($state->{count}, 3, 'count incremented to reach steady state criteria.');
    ok($detector->isSteady(), 'now steady');

    ok($detector->check(6.5), 'larger change, but reset threshold not crossed');
    $state = $detector->getState();
    is($state->{count}, 4, 'count incremented to 4');
    ok($detector->isSteady(), 'still steady');

    ok(!$detector->check(6.27), 'moderate change, reset threshold crossed');
    $state = $detector->getState();
    is($state->{count}, 0, 'count reset to 0');
    ok(!$detector->isSteady(), 'not steady any more');

};

sub stepResponse {
  my ($time, $tau, $initial, $final) = @_;
  my $response = $initial + ($final - $initial) * (1 - exp(-$time / $tau));
  return $response;
}

# Test realistic scenario
subtest 'real-ish scenario' => sub {
    my $detector = HP::SteadyStateDetector->new(
        smoothing => 0.9,
        threshold => 0.001,
        samples => 5,
    );
    
    note('Ascending step response');
    my $time = 0;
    my $value = 0;
    while ($time < 12 && !$detector->check($value)) {
      $time += 0.1;
      $value = stepResponse($time, 1, 0, 100);
    }
    ok($detector->isSteady(), 'steady state should have been detected');
    is($time,  11.9, 'steady state should be detected at time = 11.9');

    note('Descending step response');
    $detector->reset();

    $time = 0;
    $value = 100;
    while ($time < 12 && !$detector->check($value)) {
      $time += 0.1;
      $value = stepResponse($time, 0.75, 100, 0);
    }
    ok($detector->isSteady(), 'steady state should have been detected');
    is($time,  10.9, 'steady state should be detected at time = 10.9');
    
};

done_testing; 