#!/usr/bin/perl

use strict;
use warnings;
use Algorithm::CurveFit;

# Example data — an array of hashes with { time => ..., temp => ... }
my @readings = (
    { time => 0,   temp => 25 },
    { time => 10,  temp => 40 },
    { time => 20,  temp => 50 },
    { time => 50,  temp => 70 },
    { time => 100, temp => 85 },
    { time => 200, temp => 95 },
);

# Split into x and y arrays
my @xdata = map { $_->{time} } @readings;
my @ydata = map { $_->{temp} } @readings;

# Estimate T_final (approx last temp) and T_initial
my $T_initial = $ydata[0];
my $T_final   = $ydata[-1];

# Rough time constant estimate:
# Find t at ~63% of (T_final-T_initial), say first point past this temp
my $target = $T_initial + 0.63 * ($T_final - $T_initial);
my $tau_guess = $xdata[-1]; # fallback

foreach my $i (0..$#xdata) {
    if ($ydata[$i] >= $target) {
        $tau_guess = $xdata[$i];
        last;
    }
}

print "Initial guesses: T_initial=$T_initial, T_final=$T_final, tau=$tau_guess\n";

# Fit model: T(t) = T_final - (T_final - T_initial)*EULER**(-t/tau)
my $formula = "$T_initial - (T_final - $T_initial) * EULER ^ ( -x / tau )";

# Initial guesses as hash ref
my $params = [ [ T_final => $T_final, 0.01 ]
             , [ tau     => $tau_guess, 0.01 ]
             ];

# Fit
my $square_residuals = Algorithm::CurveFit::curve_fit(
    formula => $formula,
    params  => $params,
    variable => "x",
    xdata   => \@xdata,
    ydata   => \@ydata,
    maximum_iterations => 1000,
);

print "Best fit params:\n";
printf "T_initial = %.3f\nT_final = %.3f\ntau = %.3f\n",
    $params->{T_initial}, $params->{T_final}, $params->{tau};

print "Residual sum-of-squares: $square_residuals\n";


