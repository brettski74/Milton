#!/usr/bin/perl

use lib '.';
use HP::ThermalModel;
use HP::PiecewiseLinear;

# Build a piecewise linear estimator for the reflow profile
my $profile = HP::PiecewiseLinear->new(0, 20);
my $t = 0;
for my $p ( ( [ 30, 110 ]
            , [ 140, 180 ]
            , [ 160, 210 ]
            , [ 170, 210 ]
            , [ 280, 100 ]
            ) ) {
  $t += $p->[0];
  $profile->addPoint($t, $p->[1]);
}

my $PERIOD = 1.5;

# Create a thermal model for the test data
my $model = HP::ThermalModel->new({ ambient => 20
                                  , period => $PERIOD
                                  , resistance => 2.4
                                  , capacity => 24
                                  });

# Generate 31 samples of data
my $sts = { voltage }

