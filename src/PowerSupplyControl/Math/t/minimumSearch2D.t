#!/usr/bin/perl

use lib qw(.);
use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Math::Util qw(minimumSearch2D setDebug setDebugWriter);
use PowerSupplyControl::ValueTools qw(readCSVData dirname);

setDebug($ENV{DEBUG});
setDebugWriter(sub { diag(@_); });

sub quadratic {
  my ($x, $a, $b, $c) = @_;
  return ($a * $x + $b) * $x + $c;
}

subtest 'quadratic function' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53);
  };
  my @x = minimumSearch2D($fn, [ 0, 10 ], [0, 10]);
  is($x[0], float(5, tolerance => 0.01), 'x1');
  is($x[1], float(7, tolerance => 0.01), 'x2');

  # Make the search space lower bounded on the solution
  @x = minimumSearch2D($fn, [ 5, 10 ], [0, 10]);
  is($x[0], float(5, tolerance => 0.01), 'x1 - lower-bounded on solution');
  is($x[1], float(7, tolerance => 0.01), 'x2 - lower-bounded on solution');

  # Make the search space upper bounded on the solution
  @x = minimumSearch2D($fn, [ 0, 10 ], [0, 7]);
  is($x[0], float(5, tolerance => 0.01), 'x1 - upper-bounded on solution');
  is($x[1], float(7, tolerance => 0.01), 'x2 - upper-bounded on solution');

  # Lower-constrain the solution on the actual minimum
  @x = minimumSearch2D($fn, [ 5, 10 ], [0, 10], lower_constraint => [5, undef]);
  is($x[0], float(5, tolerance => 0.01), 'x1 - lower-constrained on solution');
  is($x[1], float(7, tolerance => 0.01), 'x2 - lower-constrained on solution');

  # Upper-constrain the solution on the actual minimum
  @x = minimumSearch2D($fn, [ 0, 4 ], [0, 7], 'upper-constraint' => [ undef, 7 ]);
  is($x[0], float(5, tolerance => 0.01), 'x1 - upper-constrained on solution');
  is($x[1], float(7, tolerance => 0.01), 'x2 - upper-constrained on solution');

  # Lower-constrain the solution above the actual minimum
  @x = minimumSearch2D($fn, [ 6, 10 ], [9, 18], 'lower-constraint' => [undef, 8]);
  is($x[0], float(5, tolerance => 0.01), 'x1 - lower-constrained above solution');
  is($x[1], float(8, tolerance => 0.01), 'x2 - lower-constrained above solution');

  # Upper-constrain the solution below the actual minimum
  @x = minimumSearch2D($fn, [ 0, 4 ], [0, 6], 'upper-constraint' => [ 4.5, undef ]);
  is($x[0], float(4.5, tolerance => 0.01), 'x1 - upper-constrained below solution');
  is($x[1], float(7, tolerance => 0.01), 'x2 - upper-constrained below solution');

};

subtest 'failure cases' => sub {
  my $fn = sub {
    return quadratic(shift, 1, -10, 29) + quadratic(shift, 1, -14, 53);
  };

  like(dies { minimumSearch2D($fn, [ 0, 10 ], [0, 10], steps => 3); }, qr/at least .* steps/i, 'Insufficient steps');
  like(dies { minimumSearch2D($fn, [ 0, 10 ], [10, 0]); }, qr/out of order/i, 'Reversed search bounds');
  like(dies { minimumSearch2D($fn, [ 1e6, 1e6+1 ], [0, 10], steps => 5, depth => 10); }, qr/depth exceeded/i, 'Search depth exceeded');
};


SKIP: {
  skip 'Prediction algorithms changing - not a great test unless/until algorithms are stable.', 1;

subtest 'reflow profile fitting' => sub {
  my $path = dirname(__FILE__);
  my $data = readCSVData("$path/filter-data-2d.csv") || die "Failed to read filter-data-2d.csv";
  my $period = 1.5;
  my $temp_threshold = 100;

  my $fn = sub {
    my ($tau1, $tau2) = @_;

    my $alpha1 = $period / ($period + $tau1);
    my $alpha2 = $period / ($period + $tau2);
    my $sum2 = 0;

    my $predicted = $data->[0]->{temperature};
    my $T0 = $data->[0]->{'device-temperature'};

    foreach my $row (@$data) {
      my $input = $row->{temperature};
      my $actual = $row->{'device-temperature'};
      $predicted = $alpha2 * $input + (1-$alpha2) * ($alpha1 * $T0 + (1-$alpha1) * $predicted);

      if ($input > $temp_threshold) {
        my $error = $actual - $predicted;
        $sum2 += $error * $error;
      }
    }

    return $sum2;
  };

  print "First Best: ". $fn->(276.31, 19.72) ."\n";

  my ($tau1, $tau2) = minimumSearch2D($fn, [ 1, 400 ], [ 1, 40 ], steps => 30, lower_constraint => [ 0, 0 ]);
  is($tau1, float(170, tolerance => 0.01), 'tau1');
  is($tau2, float(20, tolerance => 0.01), 'tau2');
};
}

done_testing;