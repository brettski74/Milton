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
  
  my $result = minimumSearch($fn, [ [ 0, 10 ] ]);
  is($result, float(5, tolerance => 0.01), 'basic minimum search on a quadratic, minimum witin bounds');

  $result = minimumSearch($fn, [ [ 1, 5 ] ]);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is at upper bound');

  $result = minimumSearch($fn, [ [ 5, 10 ] ]);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is at lower bound');

  $result = minimumSearch($fn, [ [ 10, 20 ] ]);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is below lower bound');
  
  $result = minimumSearch($fn, [ [ -10, 0 ] ]);
  is($result, float(5, tolerance => 0.01), 'minimum search when minimum is above upper bound');

  $result = minimumSearch($fn, [ [ 5, 10 ] ], 'lower-constraint' => [ 5 ]);
  is($result, float(5, tolerance => 0.01), 'lower-constrained search when minimum is on lower bound');

  $result = minimumSearch($fn, [ [ 0, 5 ] ], 'upper-constraint' => [ 5 ]);
  is($result, float(5, tolerance => 0.01), 'upper-constrained search when minimum is on upper bound');

  $result = minimumSearch($fn, [ [ 6, 10 ] ], 'lower-constraint' => [ 6 ]);
  is($result, float(6, tolerance => 0.01), 'lower-constrained search when minimum is below lower bound');

  $result = minimumSearch($fn, [ [ 0, 4 ] ], 'upper-constraint' => [ 4 ]);
  is($result, float(4, tolerance => 0.01), 'upper-constrained search when minimum is above upper bound');

  $result = minimumSearch($fn, [ [ 0, 10 ] ], threshold => 0.0000001);
  is($result, float(5, tolerance => 0.0000001), 'minimum search with very small threshold');

  $result = minimumSearch($fn, [ [ 0, 10 ] ], threshold => 0.0000001, steps => 30);
  is($result, float(5, tolerance => 0.0000001), 'minimum search with very small threshold, steps=30');

};

subtest '2D quadratic function' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53);
  };

  my @x = minimumSearch($fn, [ [ 0, 10 ], [0, 10] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1');
  is($x[1], float(7, tolerance => 0.001), 'x2');

  # Make the search space lower bounded on the solution
  @x = minimumSearch($fn, [ [ 5, 10 ], [0, 10] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-bounded on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - lower-bounded on solution');

  # Make the search space upper bounded on the solution
  @x = minimumSearch($fn, [ [ 0, 10 ], [0, 7] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - upper-bounded on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - upper-bounded on solution');

  # Lower-constrain the solution on the actual minimum
  @x = minimumSearch($fn, [ [ 5, 10 ], [0, 10] ], 'lower-constraint' => [5, undef]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-constrained on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - lower-constrained on solution');

  # Upper-constrain the solution on the actual minimum
  @x = minimumSearch($fn, [ [ 0, 4 ], [0, 7] ], 'upper-constraint' => [ undef, 7 ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - upper-constrained on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - upper-constrained on solution');

  # Lower-constrain the solution above the actual minimum
  @x = minimumSearch($fn, [ [ 6, 10 ], [9, 18] ], 'lower-constraint' => [undef, 8]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-constrained above solution');
  is($x[1], float(8, tolerance => 0.001), 'x2 - lower-constrained above solution');

  # Upper-constrain the solution below the actual minimum
  @x = minimumSearch($fn, [ [ 0, 4 ], [0, 6] ], 'upper-constraint' => [ 4.5, undef ]);
  is($x[0], float(4.5, tolerance => 0.001), 'x1 - upper-constrained below solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - upper-constrained below solution');

};

subtest '3D quadratic function' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53) + quadratic(shift, 1, 8, 85);
  };
  my @x = minimumSearch($fn, [ [ 0, 10 ], [0, 10], [-10, 10] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1');
  is($x[1], float(7, tolerance => 0.001), 'x2');
  is($x[2], float(-4, tolerance => 0.001), 'x3');

  @x = minimumSearch($fn, [ [ 5, 10 ], [0, 10], [-4, 10] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-bounded on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - lower-bounded on solution');
  is($x[2], float(-4, tolerance => 0.001), 'x3 - lower-bounded on solution');

  @x = minimumSearch($fn, [ [ 0, 10 ], [0, 7], [-10, 10] ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - upper-bounded on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - upper-bounded on solution');
  is($x[2], float(-4, tolerance => 0.001), 'x3 - upper-bounded on solution');

  @x = minimumSearch($fn, [ [ 6, 10 ], [0, 10], [0, 10] ], 'lower-constraint' => [ 5, undef, undef ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-constrained on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - lower-constrained on solution');
  is($x[2], float(-4, tolerance => 0.001), 'x3 - lower-constrained on solution');

  @x = minimumSearch($fn, [ [ 0, 10 ], [0, 6], [0, 10] ], 'upper-constraint' => [ undef, 7, undef ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - upper-constrained on solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - upper-constrained on solution');
  is($x[2], float(-4, tolerance => 0.001), 'x3 - upper-constrained on solution');

  @x = minimumSearch($fn, [ [ 6, 10 ], [0, 10], [0, 10] ], 'lower-constraint' => [ 5, undef, 0 ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - lower-constrained above solution');
  is($x[1], float(7, tolerance => 0.001), 'x2 - lower-constrained above solution');
  is($x[2], float(0, tolerance => 0.001), 'x3 - lower-constrained above solution');

  @x = minimumSearch($fn, [ [ 0, 10 ], [0, 6], [-10, -0.01] ], 'upper-constraint' => [ undef, 6, 0 ]);
  is($x[0], float(5, tolerance => 0.001), 'x1 - upper-constrained below solution');
  is($x[1], float(6, tolerance => 0.001), 'x2 - upper-constrained below solution');
  is($x[2], float(-4, tolerance => 0.001), 'x3 - upper-constrained below solution');

};

subtest 'failure cases' => sub {
  #linear function y=x, has no minimum!
  my $fn = sub { return shift; };

  like(dies { minimumSearch($fn, [ [ 0, 10 ] ]); }, qr/Search depth exceeded/i, 'Search depth exceeded');
  like( dies { minimumSearch($fn, [ [ 10, 8 ] ]); }, qr/out of order/i, 'Limits reversed');
  like( dies { minimumSearch($fn, [ [ 0, 10 ] ], steps => 1); }, qr/at least \d+/i, 'Insufficient steps');

};

subtest '2D failure cases' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53);
  };

  like(dies { minimumSearch($fn, [ [ 0, 10 ], [0, 10] ], steps => 3); }, qr/at least \d+/i, 'Insufficient steps');
  like(dies { minimumSearch($fn, [ [ 0, 10 ], [10, 0] ]); }, qr/out of order/i, 'Reversed search bounds');
  like(dies { minimumSearch($fn, [ [ 1e6, 1e6+1 ], [0, 10] ], steps => 5, depth => 10); }, qr/depth exceeded/i, 'Search depth exceeded');
};

subtest '3D failure cases' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53) + quadratic(shift, 1, 8, 85);
  };

  like(dies { minimumSearch($fn, [ [ 0, 10 ], [0, 10], [-10, 10] ], steps => 3); }, qr/at least \d+/i, 'Insufficient steps');
  like(dies { minimumSearch($fn, [ [ 0, 10 ], [1e6, 1e6+1], [-10, 10] ], steps => 10, depth => 10); }, qr/depth exceeded/i, 'Search depth exceeded');
  like(dies { minimumSearch($fn, [ [ 10, 0 ], [0, 10], [-10, 10] ]); }, qr/out of order/i, 'Reversed search bounds');
  like(dies { minimumSearch($fn, [ [ 0, 0 ], [11, 10], [-10, 10] ]); }, qr/out of order/i, 'Reversed search bounds');
  like(dies { minimumSearch($fn, [ [ 0, 10 ], [0, 10], [-10, -15] ]); }, qr/out of order/i, 'Reversed search bounds');
};

SKIP: {
  skip('Skipping low pass filter best fit test while algorithms are not stable.');

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
}

done_testing; 