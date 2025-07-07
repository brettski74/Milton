#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Math::PiecewiseLinear;

# Test basic constructor
note("Testing constructor");
my $pwl = PowerSupplyControl::Math::PiecewiseLinear->new();
isa_ok($pwl, 'PowerSupplyControl::Math::PiecewiseLinear');
is($pwl->length(), 0, 'New estimator should have 0 points');

# Test adding single point
note("Testing single point addition");
$pwl->addPoint(10, 10);
is($pwl->length(), 1, 'Should have 1 point after adding');
is($pwl->estimate(10), 10, 'Should return exact value for existing point');

# Test adding multiple points
note("Testing multiple point addition");
$pwl->addPoint(0, 0, 30, 90, 20, 40);
is($pwl->length(), 4, 'Should have 4 points total');

# Test that points are sorted by x value
my @points = $pwl->getPoints;
is($points[0]->[0], 0, 'First point x should be 0');
is($points[1]->[0], 10, 'Second point x should be 10');
is($points[2]->[0], 20, 'Third point x should be 20');
is($points[3]->[0], 30, 'Fourth point x should be 30');

# Check the start and end points
is($pwl->start(), 0, 'Start point should be 0');
is($pwl->end(), 30, 'End point should be 30');

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
my $pwl3 = PowerSupplyControl::Math::PiecewiseLinear->new();
my $result = $pwl3->addPoint(1, 2)->addPoint(3, 4);
isa_ok($result, 'PowerSupplyControl::Math::PiecewiseLinear');
is($result->length(), 2, 'Should have 2 points after chaining');
is($result->estimate(1), 2, 'Should return exact value for existing point');
is($result->estimate(3), 4, 'Should return exact value for existing point');

# Test with single point (edge case)
note("Testing single point edge case");
my $pwl4 = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl4->addPoint(5, 10);
is($pwl4->estimate(5), 10, 'Single point should return exact value');
is($pwl4->estimate(0), 10, 'Extrapolate below single point should return point value');
is($pwl4->estimate(10), 10, 'Extrapolate above single point should return point value');

# Test with two points
note("Testing two points");
my $pwl5 = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl5->addPoint(0, 0, 10, 20);
is($pwl5->estimate(5), 10, 'Interpolate between two points');
is($pwl5->estimate(-5), -10, 'Extrapolate below two points');
is($pwl5->estimate(15), 30, 'Extrapolate above two points');

# Test named points and segment naming
note("Testing addNamedPoint and segment naming");
my $pwl_named = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl_named->addNamedPoint(0, 0, 'A', 10, 20, 'B', 20, 40, 'C');

is($pwl_named->length(), 3, 'Should have 3 named points');
my @named_points = $pwl_named->getPoints;
is($named_points[0]->[2], 'A', 'First point name should be A');
is($named_points[1]->[2], 'B', 'Second point name should be B');
is($named_points[2]->[2], 'C', 'Third point name should be C');

# Test estimate in list context returns name of segment
my ($y1, $seg1) = $pwl_named->estimate(5);
is($y1, 10, 'Interpolate at x=5 should be y=10');
is($seg1, 'A', 'Segment name for x=5 should be A');

my ($y2, $seg2) = $pwl_named->estimate(15);
is($y2, 30, 'Interpolate at x=15 should be y=30');
is($seg2, 'B', 'Segment name for x=15 should be B');

# Test estimate at exact point returns value and name
my ($y3, $seg3) = $pwl_named->estimate(10);
is($y3, 20, 'Exact point at x=10 should be y=20');
is($seg3, 'B' , 'Exact match matches start of segment.');

# Test extrapolation below range returns first segment name
my ($y4, $seg4) = $pwl_named->estimate(-5);
is($seg4, 'A', 'Extrapolation below range should return first segment name');

# Test extrapolation above range returns last segment name
my ($y5, $seg5) = $pwl_named->estimate(25);
is($seg5, 'C', 'Extrapolation above range should return last segment name');

# Test mixing named and unnamed points
note("Testing mixed named and unnamed points");
my $pwl_mixed = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl_mixed->addPoint(0, 0, 10, 10);
$pwl_mixed->addNamedPoint(20, 20, 'Z');
my ($ym, $segm) = $pwl_mixed->estimate(15);
is($ym, 15, 'Interpolate at x=15 should be y=15');
is($segm, undef, 'No segment name for unnamed segment');
my ($ym2, $segm2) = $pwl_mixed->estimate(21);
is($segm2, 'Z', 'Segment name for x=19 should be Z');

# Test single named point
note("Testing single named point");
my $pwl_single_named = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl_single_named->addNamedPoint(42, 99, 'Only');
my ($ys, $segs) = $pwl_single_named->estimate(42);
is($ys, 99, 'Single named point returns correct value');
is($segs, 'Only', 'Single named point always returns name');

# Test addHashPoints method
note("Testing addHashPoints method");

# Test basic addHashPoints functionality
my $pwl_hash = PowerSupplyControl::Math::PiecewiseLinear->new();
my @hash_points = (
    { temperature => 0, power => 20 },
    { temperature => 100, power => 80 },
    { temperature => 200, power => 120 }
);

$pwl_hash->addHashPoints('temperature', 'power', @hash_points);
is($pwl_hash->length(), 3, 'Should have 3 points from hash data');

# Test that points are sorted by x value (temperature)
my @hash_points_result = $pwl_hash->getPoints;
is($hash_points_result[0]->[0], 0, 'First point temperature should be 0');
is($hash_points_result[1]->[0], 100, 'Second point temperature should be 100');
is($hash_points_result[2]->[0], 200, 'Third point temperature should be 200');

# Test interpolation with hash points
is($pwl_hash->estimate(50), 50, 'Interpolate at 50°C should be 50W');
is($pwl_hash->estimate(150), 100, 'Interpolate at 150°C should be 100W');

# Test exact point values from hash
is($pwl_hash->estimate(0), 20, 'Exact point at 0°C should be 20W');
is($pwl_hash->estimate(100), 80, 'Exact point at 100°C should be 80W');
is($pwl_hash->estimate(200), 120, 'Exact point at 200°C should be 120W');

# Test method chaining with addHashPoints
my $pwl_chain = PowerSupplyControl::Math::PiecewiseLinear->new();
my $chain_result = $pwl_chain->addHashPoints('x', 'y', 
    { x => 1, y => 2 },
    { x => 3, y => 4 }
);
isa_ok($chain_result, 'PowerSupplyControl::Math::PiecewiseLinear');
is($chain_result->length(), 2, 'Should have 2 points after chaining');

# Test addHashPoints with missing keys
my $pwl_missing = PowerSupplyControl::Math::PiecewiseLinear->new();
my @missing_key_points = (
    { temperature => 0, power => 20 },
    { temperature => 100 },  # missing power
    { power => 80 },         # missing temperature
    { temperature => 200, power => 120 }
);

$pwl_missing->addHashPoints('temperature', 'power', @missing_key_points);
is($pwl_missing->length(), 2, 'Should only add points with both keys present');

# Test addHashPoints with empty array
my $pwl_empty = PowerSupplyControl::Math::PiecewiseLinear->new();
$pwl_empty->addHashPoints('x', 'y');
is($pwl_empty->length(), 0, 'Should have 0 points with empty array');

# Test addHashPoints with different key names
my $pwl_diff_keys = PowerSupplyControl::Math::PiecewiseLinear->new();
my @diff_key_points = (
    { resistance => 100, temp => 25 },
    { resistance => 200, temp => 50 },
    { resistance => 300, temp => 75 }
);

$pwl_diff_keys->addHashPoints('resistance', 'temp', @diff_key_points);
is($pwl_diff_keys->length(), 3, 'Should have 3 points with different key names');
is($pwl_diff_keys->estimate(150), 37.5, 'Interpolate at resistance 150 should be temp 37.5');

# Test addHashPoints with no valid points
my $pwl_no_valid = PowerSupplyControl::Math::PiecewiseLinear->new();
my @no_valid_points = (
    { x => 10 },           # missing y
    { y => 20 },           # missing x
    { z => 30, w => 40 }   # wrong keys
);

$pwl_no_valid->addHashPoints('x', 'y', @no_valid_points);
is($pwl_no_valid->length(), 0, 'Should have 0 points when no valid points provided');

done_testing(); 