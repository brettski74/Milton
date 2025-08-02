#!/usr/bin/perl

use lib qw(.);
use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Math::Util qw(minimumSearch3D);
use PowerSupplyControl::ValueTools qw(readCSVData dirname);

subtest 'reflow profile fitting' => sub {
  my $path = dirname(__FILE__);
  my $data = readCSVData("$path/filter-data-3d.csv") || die "Failed to read filter-data-3d.csv";
  my $period = 1.5;
  my $temp_lo = 160;
  my $temp_hi = 1000;

  my $fn = sub {
    my ($tau, $a, $b) = @_;

    my $alpha = $period / ($period + $tau);
    my $sum2 = 0;

    my $predicted = $data->[0]->{temperature};
    my $T0 = $data->[0]->{'device-temperature'};
    my $EPS = 0.0000000001;

    foreach my $row (@$data) {
      my $input = $row->{temperature};
      my $actual = $row->{'device-temperature'};
#      my $tau2 = $a * $predicted + $b;
      my $denominator = $predicted + $b;
      if (abs($denominator) < $EPS) {
        $denominator = $EPS * ($denominator > 0 ? 1 : -1);
      }
      my $tau2 = $a*$b / $denominator;
      my $alpha2 = $period / ($period + $tau2);
      $predicted = $alpha * $input + (1-$alpha) * ($alpha2 * $T0 + (1-$alpha2) * $predicted);

      if ($input > $temp_lo && $input <= $temp_hi) {
        my $error = $actual - $predicted;
        $sum2 += $error * $error;
      }
    }

    return $sum2;
  };

  my ($tau1, $a, $b) = minimumSearch3D($fn, [ [ 1, 40 ]
                                            , [ 100, 5000 ]
                                            , [ 10, 1000 ]
                                            ]
                                       , steps => 30
                                       , lower_constraint => [ 0, 0, 0 ]
                                       , threshold => [ 0.01, 1, 0.1 ]
                                       );
  is($tau1, float(170, tolerance => 0.01), 'tau1');
  is($a, float(20, tolerance => 0.01), 'a');
  is($b, float(20, tolerance => 0.01), 'b');
};

done_testing;