package HP::Math::Util;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use Exporter 'import';

our @EXPORT_OK = qw(
  mean_squared_error
);

=head1 NAME

HP::Math::Util - Mathematical utility functions for the HP Controller

=head1 SYNOPSIS

    use HP::Math::Util qw(mean_squared_error);
    
    # Calculate MSE between a function and sample data
    my $mse = mean_squared_error($function, @samples);

=head1 DESCRIPTION

This module provides mathematical utility functions used throughout the HP Controller
system for data analysis and signal processing.

=head1 FUNCTIONS

=head2 mean_squared_error($fn, @samples)

    my $mse = mean_squared_error($function, @samples);

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

    use HP::Math::Util qw(mean_squared_error);
    
    # Define a simple linear function: f(x) = 2x + 1
    my $linear_fn = sub { my $x = shift; return 2 * $x + 1; };
    
    # Sample data: [input, expected_output]
    my @samples = ([1, 3], [2, 5], [3, 7], [4, 9], [5, 11]);
    
    # Calculate MSE
    my $mse = mean_squared_error($linear_fn, @samples);
    # For perfect fit, MSE would be 0
    # For this example, MSE = (1/5) * Σ((2x+1 - sampled)²)

=head4 Function Approximation

    # Test how well a constant function approximates data
    my $constant_fn = sub { return 3.5; } # Always returns 3.5
    my @data = ([1, 3.1], [2, 3.4], [3, 3.8], [4, 3.2], [5, 3.9]);
    
    my $mse = mean_squared_error($constant_fn, @data);
    # This will give the MSE of using 3.5 as a constant approximation

=head4 Model Validation

    # Validate a temperature conversion function
    my $temp_convert = sub { 
        my $celsius = shift; 
        return $celsius * 9/5 + 32;  # Celsius to Fahrenheit
    };
    
    # Sample data: [celsius_input, expected_fahrenheit_output]
    my @samples = ([0, 32], [10, 50], [20, 68], [30, 86], [40, 104]);
    
    my $mse = mean_squared_error($temp_convert, @samples);
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
    
    my $mse = mean_squared_error($multi_param_fn, @samples);
    # Tests how well the function predicts the expected outputs

=cut

sub mean_squared_error {
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

1;