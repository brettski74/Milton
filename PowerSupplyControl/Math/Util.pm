package PowerSupplyControl::Math::Util;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use Exporter 'import';

our @EXPORT_OK = qw(
  maximum
  mean
  meanSquaredError
  minimumSearch
  minimum
);

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

  if ($hi < $lo) {
    croak 'High end of search space is less than the low end.';
  }

  my $threshold = $options{threshold} // 0.01;

  # Met threshold - return best of lo, mid, hi values
  if ($hi - $lo <= $threshold) {
    my $mid = ($lo + $hi) / 2;
    my $fnlo = $fn->($lo);
    my $fnmid = $fn->($mid);
    my $fnhi = $fn->($hi);
    
    if ($fnlo < $fnmid) {
      if ($fnlo < $fnhi) {
        return $lo;
      }
      return $hi;
    } elsif ($fnmid < $fnhi) {
      return $mid;
    }
    return $hi;
  }

  # Check search depth to prevent infinite recursion
  my $depth = $options{depth} // 100;
  if ($depth <= 0) {
    croak 'Search depth exceeded.';
  }
  $options{depth} = $depth - 1;

  my $steps = $options{steps} // 100;
  if ($steps < 4) {
    croak 'Number of steps must be greater than 4.';
  }

  my $step = ($hi - $lo) / $steps;

  my $best_x = $lo;
  my $best_y = $fn->($lo);
  my @data = ( [ $best_x, $best_y] );

  for (my $i=1-$steps; $i <= 0; $i++) {
    my $x = $hi + $step * $i;
    my $y = $fn->($x);
    push @data, [ $x, $y ];
    if ($y < $best_y) {
      $best_y = $y;
      $best_x = $x;
    }
  }

  # If minimum is at the lower boundary
  if ($best_x == $lo) {
    if ($options{lower_constrained}) {
      return minimumSearch($fn, $lo, $lo+$step, %options);
    }

    # Extend the search below the low end since the minimum may be below $lo
    return minimumSearch($fn, $lo+(1-$steps)*$step, $lo+$step, %options);
  }

  # If minimum is at the upper boundary
  if ($best_x == $hi) {
    if ($options{upper_constrained}) {
      return minimumSearch($fn, $hi-$step, $hi, %options);
    }

    # Extend the search above the high end since the minimum may be above $hi
    return minimumSearch($fn, $hi-$step, $hi+($steps-1)*$step, %options);
  }

  # We don't know which side of $idx the minimum is on, so search between -1 and +1 step around it.
  return minimumSearch($fn, $best_x - $step, $best_x + $step, %options);
}

1;