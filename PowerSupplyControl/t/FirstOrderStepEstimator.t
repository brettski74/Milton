#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib '.';
use Test2::V0;
use PowerSupplyControl::FirstOrderStepEstimator;

# Seed the random number generator for repeatable tests
srand(20250624);

# Test construction
note("Constructor and property assignment");
my $est = PowerSupplyControl::FirstOrderStepEstimator->new(resistance => 10);
isa_ok($est, 'PowerSupplyControl::FirstOrderStepEstimator');
is($est->{resistance}, 10, 'Resistance set');

# Test fitting a simple exponential (simulate T(t) = 100 - 100*exp(-t/20))
note("Fitting a simple first-order step response");
my $data = generateDataSet(0, 100, 20, 0);
my ($initial, $final, $step, $direction, $threshold) = $est->_setupResponseParameters($data, 'temp', 'time');
is($initial, 0, 'Initial value set');
is($final, float(99.3262, tolerance => 0.0001), 'Final value set');
is($step, float(99.3262, tolerance => 1), 'Step value set');
is($direction, 1, 'Direction set');
is($threshold, float(0.8*99.3262, tolerance => 0.001), 'Threshold set');

($initial, $final, $step, $direction, $threshold) = $est->_setupResponseParameters($data, 'temp', 'time', { final => 101, initial => 1 });
is($initial, 1, 'Explicit Initial value set');
is($final, 101, 'Explicit Final value set');
is($step, 100, 'Step value set (explicit)');
is($direction, 1, 'Direction set (explicit)');
is($threshold, 81, 'Threshold set (explicit)');

# Test the curve fitting with an explicit final value
my $result = $est->fitCurve($data, 'temp', 'time', final => 100);

compareResult($result
            , tau => float(20, tolerance => 0.01)
            , step => float(100, tolerance => 0.1)
            , capacitance => float(2, tolerance => 0.001)
            , resistance => float(10, tolerance => 0.001)
            );

# Test the same curve, but without providing explicit final value
note('Fitting the same curve with an implicit final value');
$result = $est->fitCurve($data, 'temp', 'time');

compareResult($result
            , capacitance => float(2, tolerance => 0.1)
            , resistance => 10
            , n => 16
            , xsum => 240
            , ysum => float(61.42701698, tolerance => 0.0001)
            , x2sum => 4960
            , xysum => float(852.3543531, tolerance => 0.0001)
            , gradient => float(-0.050773, tolerance => 0.0001)
            , intercept => float(4.600779387, tolerance => 0.0001)
            , step => float(100, tolerance => 0.5)
            , tau => float(20, tolerance => 0.5)
            );

# Test with no resistance (capacitance should be undefined)
note("No resistance provided");
my $est2 = PowerSupplyControl::FirstOrderStepEstimator->new(resistance => 0);
$result = $est2->fitCurve($data, 'temp', 'time');
compareResult($result
            , capacitance => undef
            , resistance => undef
            );

# Test with missing resistance (capacitance should be undefined)
note("Missing resistance");
my $est3 = PowerSupplyControl::FirstOrderStepEstimator->new();
$result = $est3->fitCurve($data, 'temp', 'time');
compareResult($result
            , capacitance => undef
            , resistance => undef
            );

# Cooling down dataset
note("Cooling down dataset");
my $data2 = generateDataSet(180, 20, 45);
my $est4 = PowerSupplyControl::FirstOrderStepEstimator->new(resistance => 2.5);
$result = $est4->fitCurve($data2, 'temp', 'time', final => 20);
compareResult($result
            , tau => float(45, tolerance => 0.0001)
            , step => float(-160, tolerance => 1)
            , capacitance => float(18, tolerance => 0.0001)
            , resistance => 2.5
            , n => 17
            , xsum => 612
            , ysum => float(72.67795486, tolerance => 0.0001)
            , x2sum => 30294
            , xysum => float(2432.806375, tolerance => 0.0001)
            , gradient => float(-0.022222, tolerance => 0.0001)
            , intercept => float(5.075173815, tolerance => 0.0001)
            );

$result = $est4->fitCurve($data2, 'temp', 'time');
compareResult($result
            , tau => float(45, tolerance => 0.7)
            , step => float(-160, tolerance => 2)
            , capacitance => float(18, tolerance => 0.3)
            , resistance => 2.5
            , n => 16
            , xsum => 540
            , ysum => float(68.94707504, tolerance => 0.0001)
            , x2sum => 25110
            , xysum => float(2171.599254, tolerance => 0.0001)
            , gradient => float(-0.022566, tolerance => 0.0001)
            , intercept => float(5.070783017, tolerance => 0.0001)
            );

done_testing();

sub compareResult {
  my ($result, %expected) = @_;

  foreach my $key (sort keys %expected) {
    is($result->{$key}, $expected{$key}, "Estimated $key is within tolerance");
  }
}

# Helper for generating a data set for testing
# Generate data out to 5 x tau, with 10 points per tau
sub generateDataSet {
  my ($initial, $final, $tau, $noise) = @_;
  my $data = [];
  my $step = $final - $initial;
  my $time = 0;
  for (my $rt=0; $rt<=5; $rt+=0.1) {
    my $time = $rt * $tau;

    my $temp = $final - $step * exp(-$time/$tau);

    if ($noise) {
      $temp += ($noise * 2 * rand() - $noise);
    }

    push @$data, { time => $time, temp => $temp };
  }
  return $data;
}