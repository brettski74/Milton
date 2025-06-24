#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib '.';
use Test2::V0;
use HP::FirstOrderStepEstimator;

# Test construction
note("Constructor and property assignment");
my $est = HP::FirstOrderStepEstimator->new(0, 100, 10);
isa_ok($est, 'HP::FirstOrderStepEstimator');
is($est->{initial}, 0, 'Initial value set');
is($est->{final}, 100, 'Final value set');
is($est->{resistance}, 10, 'Resistance set');

# Test fitting a simple exponential (simulate T(t) = 100 - 100*exp(-t/20))
note("Fitting a simple first-order step response");
my $data = [
    { time => 0,   value => 0 },
    { time => 5,   value => 22.12 },
    { time => 10,  value => 39.35 },
    { time => 12,  value => 47.00 },
    { time => 14,  value => 53.00 },
    { time => 16,  value => 57.50 },
    { time => 18,  value => 60.50 },
    { time => 20,  value => 63.21 }, # This is the 63.2% point
    { time => 22,  value => 65.00 }, # Above threshold, will be ignored
    { time => 30,  value => 77.69 },
    { time => 40,  value => 86.47 },
    { time => 50,  value => 91.79 },
    { time => 60,  value => 95.02 },
    { time => 70,  value => 97.27 },
    { time => 80,  value => 98.65 },
    { time => 90,  value => 99.33 },
    { time => 100, value => 99.66 },
];

$est->setData($data, 'value', 'time');
ok(defined $est->{tau}, 'Tau is defined');
ok(defined $est->{step}, 'Step is defined');
ok(defined $est->{capacitance}, 'Capacitance is defined');
is($est->{tau}, float(20, precision => 0.5), 'Estimated tau is close to 20');
is($est->{step}, float(100, precision => 1), 'Estimated step is close to 100');
is($est->{capacitance}, float(2, precision => 0.1), 'Estimated capacitance is close to 2');

# Test with no resistance (capacitance should be undefined)
note("No resistance provided");
my $est2 = HP::FirstOrderStepEstimator->new(0, 100, 0);
$est2->setData($data, 'value', 'time');
ok(!defined $est2->{capacitance}, 'Capacitance is undefined if resistance is zero');

# Test with missing resistance (capacitance should be undefined)
note("Missing resistance");
my $est3 = HP::FirstOrderStepEstimator->new(0, 100);
$est3->setData($data, 'value', 'time');
ok(!defined $est3->{capacitance}, 'Capacitance is undefined if resistance is missing');

# Test method chaining
note("Method chaining");
my $est4 = HP::FirstOrderStepEstimator->new(0, 100, 10);
my $ret = $est4->setData($data, 'value', 'time');
is($ret, $est4, 'setData returns self for chaining');

done_testing();

# Helper for approximate comparison
sub is_approx {
    my ($got, $expected, $tol, $msg) = @_;
    ok(abs($got - $expected) <= $tol, $msg // "approx $expected");
}