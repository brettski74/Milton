package PowerSupplyControl::Math::Util;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use Exporter 'import';
use Time::HiRes qw(time);

our @EXPORT_OK = qw(
  maximum
  mean
  meanSquaredError
  minimum
  minimumSearch
  minimumSearch2D
  minimumSearch3D
  setDebug
  setDebugWriter
);

my $DEBUG = 0;
my $DEBUG_WRITER = undef;

=head1 NAME

PowerSupplyControl::Math::Util - Mathematical utility functions for the HP Controller

=head1 SYNOPSIS

    use PowerSupplyControl::Math::Util qw(meanSquaredError);
    
    # Calculate MSE between a function and sample data
    my $mse = meanSquaredError($function, @samples);

=head1 DESCRIPTION

This module provides mathematical utility functions used throughout the HP Controller
system for data analysis and signal processing.

=head1 FUNCTIONS

=head2 meanSquaredError($fn, @samples)

    my $mse = meanSquaredError($function, @samples);

Calculates the Mean Squared Error (MSE) between a function and a set of sample data points.

The MSE is a measure of the average squared difference between predicted values
(from the function) and actual values (from the samples). It's commonly used in
statistics and machine learning to assess the quality of a model or function fit.

=head3 Theory

The Mean Squared Error is calculated as:

    MSE = (1/n) * Σ(y_predicted - y_actual)²

Where:
- n is the number of samples
- y_predicted is the value returned by the function for each input
- y_actual is the actual output value from the sample

=head3 Parameters

=over 4

=item $function

A code reference (subroutine reference) representing the expected function relating inputs
to outputs. The function should take each sample array and return a predicted result value.
The sample array will not be altered and so will include the sampled result. It is up to the
caller to make sure the provided subroutine ignores the sampled result value. The subroutine
must not alter the provided sample array.

=item @samples

A list of sample data points. Each sample should be a reference to an array with two elements.
The first element is the input value and the second element is the sampled result for that input.
The input value is what will be passed to your expected function. The result value is what will
be compared to the output of your expected function.

=back

=head3 Returns

Returns a scalar value representing the mean squared error. The result is always
non-negative, with lower values indicating better agreement between the function
and the sample data.

=head3 Examples

=head4 Basic Usage

    use PowerSupplyControl::Math::Util qw(meanSquaredError);
    
    # Define a simple linear function: f(x) = 2x + 1
    my $linear_fn = sub { my $x = shift; return 2 * $x + 1; };
    
    # Sample data: [input, expected_output]
    my @samples = ([1, 3], [2, 5], [3, 7], [4, 9], [5, 11]);
    
    # Calculate MSE
    my $mse = meanSquaredError($linear_fn, @samples);
    # For perfect fit, MSE would be 0
    # For this example, MSE = (1/5) * Σ((2x+1 - sampled)²)

=head4 Function Approximation

    # Test how well a constant function approximates data
    my $constant_fn = sub { return 3.5; } # Always returns 3.5
    my @data = ([1, 3.1], [2, 3.4], [3, 3.8], [4, 3.2], [5, 3.9]);
    
    my $mse = meanSquaredError($constant_fn, @data);
    # This will give the MSE of using 3.5 as a constant approximation

=head4 Model Validation

    # Validate a temperature conversion function
    my $temp_convert = sub { 
        my $celsius = shift; 
        return $celsius * 9/5 + 32;  # Celsius to Fahrenheit
    };
    
    # Sample data: [celsius_input, expected_fahrenheit_output]
    my @samples = ([0, 32], [10, 50], [20, 68], [30, 86], [40, 104]);
    
    my $mse = meanSquaredError($temp_convert, @samples);
    # Perfect conversion should give MSE = 0

=head4 Multi-parameter Function

    # Function with multiple inputs: f(x, y) = x + 2*y
    my $multi_param_fn = sub {
        my @sample = @_;
        my $x = $sample[0];  # First input
        my $y = $sample[1];  # Second input
        return $x + 2 * $y;  # Predicted output
    };
    
    # Sample data: [x, y, expected_output]
    my @samples = ([1, 2, 5], [3, 1, 5], [0, 3, 6], [2, 2, 6]);
    
    my $mse = meanSquaredError($multi_param_fn, @samples);
    # Tests how well the function predicts the expected outputs

=cut

sub meanSquaredError {
  my ($fn, @samples) = @_;

  croak 'No samples provided.' unless @samples;
  croak 'Expected function is not a code reference.' unless reftype($fn) eq 'CODE';

  my $sum = 0;
  for (my $idx = 0; $idx < @samples; $idx++) {
    my $sample = $samples[$idx];
    croak "Sample $idx is not an array reference." unless reftype($sample) eq 'ARRAY';
    croak "Sample $idx has less than 2 elements." unless @$sample >= 2;

    my $error = $fn->(@{$samples[$idx]}) - $samples[$idx]->[-1];
    $sum += $error * $error;
  }

  return $sum / scalar(@samples);
}

=head2 mean($values, $key1, $val1{, $key2, $val2, ...})

Calculate mean values from a list of hashes.

=over

=item $values

A reference to a list of hash references.

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be averaged will be taken.

=item $val1, $val2, ..., $valN

The set of variables to which the mean values will be assigned.

=cut

sub mean {
  my $values = shift;
  my @count = ();

  for (my $idx = 1; $idx < @_; $idx += 2) {
    $_[$idx] = undef;
    $count[$idx] = 0;
  }

  foreach my $row (@$values) {
    for (my $idx = 1; $idx < @_; $idx += 2) {
      my $key = $_[$idx-1];
      
      if (defined $row->{$key}) {
        $_[$idx] += $row->{$key};
        $count[$idx]++;
      }
    }
  }

  for (my $idx = 1; $idx < @_; $idx += 2) {
    $_[$idx] /= $count[$idx] if defined($_[$idx]) && $count[$idx] > 0;
  }

  return;
}

=head2 minimum($values, $key1, $val1{, $key2, $val2, ...})

Calculate the minimum value from a list of hashes.

=over

=item $values

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be reviewed.

=item $val1, $val2, ..., $valN

The set of variables to which the minimum values will be assigned.

=cut

sub minimum {
  my $values = shift;

  for (my $i=1; $i < @_; $i += 2) {
    $_[$i] = undef;
  }

  foreach my $row (@$values) {
    for (my $i = 1; $i < @_; $i += 2) {
      my $key = $_[$i-1];
      if (defined $row->{$key}) {
        if (!defined($_[$i]) || $_[$i] > $row->{$key}) {
          $_[$i] = $row->{$key};
        }
      }
    }
  }

  return;
}

=head2 maximum($values, $key1, $val1{, $key2, $val2, ...})

Calculate the maximum value from a list of hashes.

=over

=item $values

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be reviewed.

=item $val1, $val2, ..., $valN

The set of variables to which the maximum values will be assigned.

=cut

sub maximum {
  my $values = shift;

  for (my $i=1; $i < @_; $i += 2) {
    $_[$i] = undef;
  }

  foreach my $row (@$values) {
    for (my $i = 1; $i < @_; $i += 2) {
      my $key = $_[$i-1];
      if (defined $row->{$key}) {
        if (!defined($_[$i]) || $_[$i] < $row->{$key}) {
          $_[$i] = $row->{$key};
        }
      }
    }
  }

  return;
}

=head2 minimumSearch($fn, $lo, $hi, $steps, $threshold, %options)

Search for the minimum value of a univariate function. The search will continue
recursively on smaller and smaller sub-ranges until the difference between $lo
and $hi is less than or equal to a $threshold.

=over

=item $fn

A code reference representing the function to be searched. The function must take a
single scalar argument and return a scalar value.

=item $lo

The minimum value of the search space.

=item $hi

The maximum value of the search space.

=item %options

Additional optional named parameters that may be supplied.

=over

=item steps

the number of steps into which the search space will be divided. If not specified, defaults to 100.

=item $threshold

The maximum value allowed between $lo and $hi. If the difference between $lo and $hi is less than this value,
the search will stop and return the average of $lo and $hi. If not specified, defaults to 0.01.

=item $lower_constrained

If true, the search will never search below $lo. Defaults to false.

=item $upper_constrained

If true, the search will never search above $hi. Defaults to false.

=back

=item Return Value

Returns the value of the independent variable that produces the minimum value of the
provided function.

=back

=cut

sub minimumSearch {
  my ($fn, $lo, $hi, %options) = @_;
  my $start = time;

  if ($hi < $lo) {
    croak 'High end of search space is less than the low end.';
  }

  my $hi_constraint = $options{'upper-constraint'};
  my $lo_constraint = $options{'lower-constraint'};
  my $steps = $options{steps} // 100;

  croak "Must have at least 4 steps." if $steps < 4;

  my $threshold = $options{threshold} // 0.001;

  my $depth = $options{depth} // 100;

  my $elapsed = $start;
  my $re_flag = 0;

  while ($depth > 0) {
    if ($DEBUG) {
      my $msg = sprintf('limits: [ %.6f, %.6f ]'
                      , $lo
                      , $hi
                      );
      writeDebug($msg);
    }
    $depth--;

    croak "Search range limits out of order [ $lo, $hi ]" if $hi < $lo;

    my $range = $hi - $lo;
    my $step = $range / $steps;

    my $best_x = $lo;
    my $best_y = $fn->($lo);

    for (my $i=1-$steps; $i <= 0; $i++) {
      my $x = $hi + $step * $i;
      my $y = $fn->($x);
      if ($y < $best_y) {
        $best_y = $y;
        $best_x = $x;
      }
    }

    if ($range <= $threshold) {
      if ($DEBUG) {
        my $end = time;
        my $msg = sprintf("best: %.6f, elapsed: %.3f seconds", $best_x, $end - $start);
        writeDebug($msg);
      }
      return $best_x;
    }

    ($lo, $hi, $re_flag) = _new_limits($best_x, $lo, $hi, $step, $steps, $lo_constraint, $hi_constraint, $re_flag);
    if ($DEBUG) {
      my $end = time;
      my $msg = sprintf("elapsed: %.3f seconds", $end - $elapsed);
      $elapsed = $end;
      $msg .= sprintf(" range: %.6f > $threshold", $range) if $range > $threshold;
      writeDebug($msg);
    }
  }

  croak 'Search depth exceeded.';
}

sub _new_limits {
  my ($best, $lo, $hi, $step, $steps, $lo_constraint, $hi_constraint, $re_flag) = @_;
  my $bottom = $best - $step;
  my $top = $best + $step;
  
  if ($bottom < $lo) {
    if ($re_flag < 0) {
      # Range extended on the bottom twice in a row, so accelerate range extension
      $bottom -= $step * $steps * 2;
    }

    $re_flag = -1;
  } elsif ($top > $hi) {
    if ($re_flag > 0) {
      # Range extended on the top twice in a row, so accelerate range extension
      $top += $step * $steps * 2;
    }

    $re_flag = 1;
  }

  if (defined($lo_constraint) && $bottom < $lo_constraint) {
    $bottom = $lo_constraint;
    $re_flag = 0;
  }

  if (defined($hi_constraint) && $top > $hi_constraint) {
    $top = $hi_constraint;
    $re_flag = 0;
  }

  return ( $bottom, $top, $re_flag );
}

sub setDebug {
  $DEBUG = shift;
  return $DEBUG;
}

sub writeDebug {
  my ($message) = @_;
  if ($DEBUG) {
    if ($DEBUG_WRITER) {
      $DEBUG_WRITER->($message);
    } else {
      print "$message\n";
    }
  }
}

sub setDebugWriter {
  $DEBUG_WRITER = shift;
}

sub minimumSearch2D {
  my ($fn, $lim1, $lim2, %options) = @_;

  my $elapsed;
  my $start = time;

  die 'lim1 is not an array reference.' unless reftype($lim1) eq 'ARRAY';
  die 'lim2 is not an array reference.' unless reftype($lim2) eq 'ARRAY';
  die 'lim1 is out of order.' unless $lim1->[0] <= $lim1->[1];
  die 'lim2 is out of order.' unless $lim2->[0] <= $lim2->[1];

  my $threshold = $options{threshold} // [ 0.001, 0.001 ];
  if (!ref($threshold)) {
    $threshold = [ $threshold, $threshold ];
  }

  my $steps = $options{steps} // 30;
  croak "Must have at least 4 steps." if $steps < 4;

  # Copy the limits so we can work with them.
  my @limits = ( [ @$lim1 ], [ @$lim2 ] );
  $lim1 = $limits[0];
  $lim2 = $limits[1];

  # Check search depth to prevent infinite recursion
  my $depth = $options{depth} // 100;

  while ($depth > 0) {
    if ($DEBUG) {
      my $msg = sprintf('limits: [ %.6f, %.6f ], [ %.6f, %.6f ]'
                      , $lim1->[0]
                      , $lim1->[1]
                      , $lim2->[0]
                      , $lim2->[1]
                      );
      writeDebug($msg);
      $elapsed = time;
    }

    $depth--;

    my $range1 = $lim1->[1] - $lim1->[0];
    my $range2 = $lim2->[1] - $lim2->[0];

    my $step1 = $range1 / $steps;
    my $step2 = $range2 / $steps;

    my $best_y = $fn->($lim1->[0], $lim2->[0]);
    my $best_x1 = $lim1->[0];
    my $best_x2 = $lim2->[0];

    for (my $i=1-$steps; $i <= 0; $i++) {
      my $x1 = $lim1->[1] + $step1 * $i;
      for (my $j=1-$steps; $j <= 0; $j++) {
        my $x2 = $lim2->[1] + $step2 * $j;
        my $y = $fn->($x1, $x2);
        if ($y < $best_y) {
          $best_y = $y;
          $best_x1 = $x1;
          $best_x2 = $x2;
        }
      }
    }

    if ($range1 <= $threshold->[0] && $range2 <= $threshold->[1]) {
      if ($DEBUG) {
        my $end = time;
        writeDebug(sprintf("best: [ %.6f, %.6f ], elapsed: %.3f seconds", $best_x1, $best_x2, $end - $start));
      }
      return ( $best_x1, $best_x2 );
    } else {
      if ($DEBUG) {
        my $end = time;
        my $msg = sprintf("elapsed: %.3f seconds", $end - $elapsed);
        $elapsed = $end;
        $msg .= sprintf(" range1: %.6f > $threshold->[0]", $range1) if $range1 > $threshold->[0];
        $msg .= sprintf(" range2: %.6f > $threshold->[1]", $range2) if $range2 > $threshold->[1];
        writeDebug($msg);
      }
    }

    @$lim1 = _new_limits($best_x1, $lim1->[0], $lim1->[1], $step1, $steps, $options{'lower-constraint'}->[0], $options{'upper-constraint'}->[0], $lim1->[2]);
    @$lim2 = _new_limits($best_x2, $lim2->[0], $lim2->[1], $step2, $steps, $options{'lower-constraint'}->[1], $options{'upper-constraint'}->[1], $lim2->[2]);
  }

  croak 'Search depth exceeded.';
  return;
}

sub minimumSearch3D {
  my ($fn, $limits, %options) = @_;
  my $start = time;

  my $elapsed;
  if ($DEBUG) {
    $elapsed = time;
    my $msg = sprintf('limits: [ %.6f, %.6f ], [ %.6f, %.6f ], [ %.6f, %.6f ]'
                    , @{$limits->[0]}
                    , @{$limits->[1]}
                    , @{$limits->[2]}
                    );
    writeDebug($msg);
  }

  die 'limits[0] is not an array reference.' unless reftype($limits->[0]) eq 'ARRAY';
  die 'limits[1] is not an array reference.' unless reftype($limits->[1]) eq 'ARRAY';
  die 'limits[2] is not an array reference.' unless reftype($limits->[2]) eq 'ARRAY';
  die 'limits[0] is out of order ['. join(', ', @{$limits->[0]}) . ']' unless $limits->[0]->[0] <= $limits->[0]->[1];
  die 'limits[1] is out of order ['. join(', ', @{$limits->[1]}) . ']' unless $limits->[1]->[0] <= $limits->[1]->[1];
  die 'limits[2] is out of order ['. join(', ', @{$limits->[2]}) . ']' unless $limits->[2]->[0] <= $limits->[2]->[1];

  # Check search depth to prevent infinite recursion
  my $depth = $options{depth} // 100;
  if ($depth <= 0) {
    croak 'Search depth exceeded.';
  }
  $options{depth} = $depth - 1;

  my $threshold = $options{threshold} // [ 0.01, 0.01, 0.01 ];
  if (!ref($threshold)) {
    $threshold = [ $threshold, $threshold, $threshold ];
  }

  my $steps = $options{steps} // 24;
  my $range1 = $limits->[0]->[1] - $limits->[0]->[0];
  my $range2 = $limits->[1]->[1] - $limits->[1]->[0];
  my $range3 = $limits->[2]->[1] - $limits->[2]->[0];
  my $step1 = $range1 / $steps;
  my $step2 = $range2 / $steps;
  my $step3 = $range3 / $steps;

  my $best_y = $fn->($limits->[0]->[0], $limits->[1]->[0], $limits->[2]->[0]);
  my $best_x1 = $limits->[0]->[0];
  my $best_x2 = $limits->[1]->[0];
  my $best_x3 = $limits->[2]->[0];

  for (my $i=1-$steps; $i <= 0; $i++) {
    my $x1 = $limits->[0]->[1] + $step1 * $i;
    for (my $j=1-$steps; $j <= 0; $j++) {
      my $x2 = $limits->[1]->[1] + $step2 * $j;
      for (my $k=1-$steps; $k <= 0; $k++) {
        my $x3 = $limits->[2]->[1] + $step3 * $k;
        my $y = $fn->($x1, $x2, $x3);
        if ($y < $best_y) {
          $best_y = $y;
          $best_x1 = $x1;
          $best_x2 = $x2;
          $best_x3 = $x3;
        }
      }
    }
  }

  if ($range1 <= $threshold->[0] && $range2 <= $threshold->[1] && $range3 <= $threshold->[2]) {
    if ($DEBUG) {
      my $end = time;
      my $msg = sprintf("best: [ %.6f, %.6f, %.6f ], elapsed: %.3f seconds", $best_x1, $best_x2, $best_x3, $end - $start);
      writeDebug($msg);
    }
    return ( $best_x1, $best_x2, $best_x3 );
  } else {
    if ($DEBUG) {
      $elapsed = time - $elapsed;
      my $msg = sprintf("elapsed: %.3f seconds", $elapsed);
      $msg .= sprintf(" range1: %.6f > $threshold->[0]", $range1) if $range1 > $threshold->[0];
      $msg .= sprintf(" range2: %.6f > $threshold->[1]", $range2) if $range2 > $threshold->[1];
      $msg .= sprintf(" range3: %.6f > $threshold->[2]", $range3) if $range3 > $threshold->[2];
      writeDebug($msg);
    }
  }

  my ($new_lo1, $new_hi1) = _new_limits($best_x1, $limits->[0]->[0], $limits->[0]->[1], $step1, $steps, $options{lower_constraint}->[0], $options{upper_constraint}->[0]);
  my ($new_lo2, $new_hi2) = _new_limits($best_x2, $limits->[1]->[0], $limits->[1]->[1], $step2, $steps, $options{lower_constraint}->[1], $options{upper_constraint}->[1]);
  my ($new_lo3, $new_hi3) = _new_limits($best_x3, $limits->[2]->[0], $limits->[2]->[1], $step3, $steps, $options{lower_constraint}->[2], $options{upper_constraint}->[2]);

  return minimumSearch3D($fn, [ [ $new_lo1, $new_hi1 ]
                              , [ $new_lo2, $new_hi2 ]
                              , [ $new_lo3, $new_hi3 ]
                              ]
                       , %options
                       );
}

1;