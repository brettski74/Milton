#!/usr/bin/perl

use lib qw(.);
use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Math::Util qw(minimumSearch2D);
use PowerSupplyControl::ValueTools qw(readCSVData dirname);

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

done_testing;