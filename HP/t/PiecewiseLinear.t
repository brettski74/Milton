#!/usr/bin/perl

use lib '.';
use Test2::V0;
use HP::PiecewiseLinear;

# Test basic constructor
note("Testing constructor");
my $pwl = HP::PiecewiseLinear->new();
isa_ok($pwl, 'HP::PiecewiseLinear');
is($pwl->length(), 0, 'New estimator should have 0 points');

# Test adding single point
note("Testing single point addition");
$pwl->addPoint(10, 10);
is($pwl->length(), 1, 'Should have 1 point after adding');
is($pwl->estimate(10), 10, 'Should return exact value for existing point');

# Test adding multiple points
note("Testing multiple point addition");
$pwl->addPoint(0, 0, 20, 40, 30, 90);
is($pwl->length(), 4, 'Should have 4 points total');

# Test that points are sorted by x value
my @points = @$pwl;
is($points[0]->[0], 0, 'First point x should be 0');
is($points[1]->[0], 10, 'Second point x should be 10');
is($points[2]->[0], 20, 'Third point x should be 20');
is($points[3]->[0], 30, 'Fourth point x should be 30');

# Test interpolation between points
note("Testing interpolation");
is($pwl->estimate(5), 5, 'Interpolate at x=5 should be y=5');
is($pwl->estimate(15), 25, 'Interpolate at x=15 should be y=25');
is($pwl->estimate(25), 65, 'Interpolate at x=25 should be y=65');

# Test exact point values
is($pwl->estimate(0), 0, 'Exact point at x=0 should be y=0');
is($pwl->estimate(10), 10, 'Exact point at x=10 should be y=10');
is($pwl->estimate(20), 40, 'Exact point at x=20 should be y=40');
is($pwl->estimate(30), 90, 'Exact point at x=30 should be y=90');

# Test extrapolation below range
note("Testing extrapolation below range");
is($pwl->estimate(-5), -5, 'Extrapolate below x=0 should use first segment gradient');
is($pwl->estimate(-10), -10, 'Extrapolate further below should continue gradient');

# Test extrapolation above range
note("Testing extrapolation above range");
is($pwl->estimate(35), 115, 'Extrapolate above x=30 should use last segment gradient');
is($pwl->estimate(40), 140, 'Extrapolate further above should continue gradient');

# Test method chaining
note("Testing method chaining");
my $pwl3 = HP::PiecewiseLinear->new();
my $result = $pwl3->addPoint(1, 2)->addPoint(3, 4);
isa_ok($result, 'HP::PiecewiseLinear');
is($result->length(), 2, 'Should have 2 points after chaining');
is($result->estimate(1), 2, 'Should return exact value for existing point');
is($result->estimate(3), 4, 'Should return exact value for existing point');

# Test with single point (edge case)
note("Testing single point edge case");
my $pwl4 = HP::PiecewiseLinear->new();
$pwl4->addPoint(5, 10);
is($pwl4->estimate(5), 10, 'Single point should return exact value');
is($pwl4->estimate(0), 10, 'Extrapolate below single point should return point value');
is($pwl4->estimate(10), 10, 'Extrapolate above single point should return point value');

# Test with two points
note("Testing two points");
my $pwl5 = HP::PiecewiseLinear->new();
$pwl5->addPoint(0, 0, 10, 20);
is($pwl5->estimate(5), 10, 'Interpolate between two points');
is($pwl5->estimate(-5), -10, 'Extrapolate below two points');
is($pwl5->estimate(15), 30, 'Extrapolate above two points');

done_testing(); 