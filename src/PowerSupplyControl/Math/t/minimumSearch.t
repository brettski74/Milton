#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib qw(.);

use Test2::V0;

use PowerSupplyControl::Math::Util qw(minimumSearch setDebug setDebugWriter);
use PowerSupplyControl::ValueTools qw(dirname readCSVData);

setDebug($ENV{DEBUG});
setDebugWriter(sub { diag(@_); });

sub quadratic {
  my ($x, $a, $b, $c) = @_;
  return ($a * $x + $b) * $x + $c;
}

subtest 'simple quadratic function' => sub {
  # f(x) = (x-5)^2 + 2 = x^2 - 10x + 29, minimum at x=5 with value 2
  my $fn = sub { return quadratic(shift, 1, -10, 29); };
  
  my $result = minimumSearch($fn, 0, 10);
  is($result, float(5, tolerance => 0.01), 'basic minimum search on a quadratic, minimum witin bounds');

  $result = minimumSearch($fn, 1, 5);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is at upper bound');

  $result = minimumSearch($fn, 5, 10);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is at lower bound');

  $result = minimumSearch($fn, 10, 20);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is below lower bound');
  
  $result = minimumSearch($fn, -10, 0);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is above upper bound');

  $result = minimumSearch($fn, 5, 10, 'lower-constraint' => 5);
  is($result, float(5, tolerance => 0.01), 'lower-constrained search when minimum is on lower bound');

  $result = minimumSearch($fn, 0, 5, 'upper-constraint' => 5);
  is($result, float(5, tolerance => 0.01), 'upper-constrained search when minimum is on upper bound');

  $result = minimumSearch($fn, 6, 10, 'lower-constraint' => 6);
  is($result, float(6, tolerance => 0.01), 'lower-constrained search when minimum is below lower bound');

  $result = minimumSearch($fn, 0, 4, 'upper-constraint' => 4);
  is($result, float(4, tolerance => 0.01), 'upper-constrained search when minimum is above upper bound');

  $result = minimumSearch($fn, 0, 10, threshold => 0.0000001);
  is($result, float(5, tolerance => 0.0000001), 'minimum search with very small threshold');

  $result = minimumSearch($fn, 0, 10, threshold => 0.0000001, steps => 30);
  is($result, float(5, tolerance => 0.0000001), 'minimum search with very small threshold, steps=30');

};

subtest 'failure cases' => sub {
  #linear function y=x, has no minimum!
  my $fn = sub { return shift; };

  like(dies { minimumSearch($fn, 0, 10); }, qr/Search depth exceeded/i, 'Search depth exceeded');
  like( dies { minimumSearch($fn, 10, 8); }, qr/High end.*less.*low end/i, 'Limits reversed');
  like( dies { minimumSearch($fn, 0, 10, steps => 1); }, qr/Must have at least 4 steps/i, 'Insufficient steps');

};

subtest 'low pass filter best fit' => sub {
  my $dir = dirname(__FILE__);
  my $data = readCSVData("$dir/filter-data-1.csv");
  my $period = 1.5;

  my $fn = sub {
    my $tau = shift;

    my $alpha = $period / ($tau + $period);
    my $alpha_1 = 1 - $alpha;

    my $e2sum = 0;
    my $iir = $data->[0]->{temperature};
    my $now = 0;

    foreach my $sample (@$data) {
      $iir = $alpha * $sample->{temperature} + $alpha_1 * $iir;
      if ($sample->{temperature} > 160) {
        my $err = $sample->{'device-temperature'} - $iir;
        $e2sum += $err * $err;
      }
    }

    return $e2sum;
  };

  #my $result = minimumSearch($fn, 0, 1000, lower_constrained => 1);
  my $result = minimumSearch($fn, 0, 200, lower_constrained => 1);
  is ($result, float(28.226912, tolerance => 0.01), 'quick, low-precision fit');

  $result = minimumSearch($fn, 0, 1000, lower_constrained => 1, threshold => 0.00001);
  is ($result, float(28.2266912, tolerance => 0.00001), 'higher precision fit');
};

done_testing; 