package PowerSupplyControl::Math::FirstOrderStepEstimator;

use strict;
use warnings qw(all -uninitialized);
use Carp;

=head1 NAME

PowerSupplyControl::Math::FirstOrderStepEstimator - First-order step response estimator for electrical/thermal systems

=head1 SYNOPSIS

    use PowerSupplyControl::Math::FirstOrderStepEstimator;
    
    # Create estimator for a thermal system
    my $estimator = PowerSupplyControl::Math::FirstOrderStepEstimator->new(
        initial => 25.0,      # Initial value (eg. temperature, voltage, etc) (°C)
        final   => 100.0,     # Final value (eg. temperature, voltage, etc) (°C)
        resistance => 10.0    # Thermal resistance (°C/W) or electrical resistance (Ω)
    );
    
    # Fit data to estimate time constant and step response
    $estimator->fitCurve($data_points, 'temperature', 'time');
    
    # Access estimated parameters
    my $tau = $estimator->{tau};           # Time constant (seconds)
    my $step = $estimator->{step};         # Step response magnitude
    my $capacitance = $estimator->{capacitance}; # Thermal capacitance (J/°C)

=head1 DESCRIPTION

PowerSupplyControl::Math::FirstOrderStepEstimator implements a first-order step response estimator for thermal systems.
It analyzes temperature vs. time data to estimate the time constant (τ) and step response
characteristics of a first-order thermal system.

The estimator uses a log-linear curve-fitting approach to estimate the time constant and step response parameters.
This requires taking the natural logarithm of the response value relative to the final value, which then gives us
a set of linear data on which to do simple linear regression. The gradient of the resulting best fit line is
the time constant of the system. If the resistance is provided, the capacitance is calculated from the time
constant as well.

=head1 CONSTRUCTOR

=head2 new($initial, $final, $resistance)

Creates a new FirstOrderStepEstimator object.

=over

=item $initial

The initial response value of the system (eg. temperature, voltage, etc).

=item $final

The final (target) response value of the system (eg. temperature, voltage, etc).

=item $resistance

The thermal resistance of the system in degrees Celsius per watt (°C/W) or electrical resistance (Ω).
This is used to calculate the thermal capacitance or electrical capacitance. If not provided or set to 0,
the capacitance will not be calculated.

=back

Returns a blessed FirstOrderStepEstimator object.

=head1 METHODS

=head2 setRegressionThreshold($threshold)

Set the regression threshold.

When using a log-linear regression, the logarithm of the output values tends to amplify the effects of noise as
the value gets closer to the final value.  This can cause bias towards the noiser later data points. To
counteract this, the regression can be limited to values below a certain threshold, specified as a propostion
of the difference between the initial and final values. The default threshold is 0.8, which seems like a good
compromise between capturing as much of the exponential curve as possible while still being robust to noise.
If desired, this can be set to a higher or lower value as demanded by the application and the noise level in
the data.

=over

=item $threshold

The threshold to use for the regression as a proportion of the difference between the initial and final values.

=back

=head2 fitCurve($data, $ylabel, $xlabel)

Fits the provided data to estimate the first-order step response parameters.

=over

=item $data

An array reference containing hash references with time and temperature data points.
Each hash should contain the x-axis and y-axis values as specified by $xlabel and $ylabel.

=item $ylabel

The key name for the y-axis (response value) values in the data hashes.

=item $xlabel

The key name for the x-axis (time) values in the data hashes.

=back

This method performs the following calculations:

=over

=item *

Transforms the response data using: ln(final_response - current_response)

=item *

Performs linear regression on the transformed data vs. time

=item *

Calculates the time constant: τ = -1/slope

=item *

Calculates the step response magnitude: step = exp(intercept)

=item *

If resistance is provided, calculates thermal capacitance: C = τ/R

=back

Returns the estimator object for method chaining.

=head1 OBJECT PROPERTIES

After calling fitCurve(), the following properties are available:

=over

=item tau

The estimated time constant in seconds. This represents the time required for the
system to reach 63.2% of its final value.

=item step

The estimated step response magnitude. This should be close to the difference between the initial and final response values.

=item capacitance

The calculated capacitance in joules per degree Celsius (J/°C) or farads (F).
Only calculated if resistance was provided in the constructor.

=back

=head1 EXAMPLE

    # Sample data: time vs temperature measurements
    my $data = [
        { time => 0,   temperature => 25.0 },
        { time => 10,  temperature => 45.2 },
        { time => 20,  temperature => 62.1 },
        { time => 30,  temperature => 75.8 },
        { time => 40,  temperature => 85.3 },
        { time => 50,  temperature => 91.7 },
        { time => 60,  temperature => 95.2 }
    ];
    
    # Create estimator
    my $estimator = PowerSupplyControl::Math::FirstOrderStepEstimator->new(
        initial => 25.0,
        final   => 100.0,
        resistance => 5.0
    );
    
    # Fit the data
    $estimator->fitCurve($data, 'temperature', 'time');
    
    # Results
    print "Time constant: $estimator->{tau} seconds\n";
    print "Thermal capacitance: $estimator->{capacitance} J/°C\n";

=head1 THEORY

The first-order step response follows the equation:

    T(t) = T_final - (T_final - T_initial) * exp(-t/τ)

Where:
- T(t) is the temperature at time t
- T_final is the final temperature
- T_initial is the initial temperature
- τ (tau) is the time constant

Taking the natural logarithm of both sides:

    ln(T_final - T(t)) = ln(T_final - T_initial) - t/τ

This is a linear equation in the form y = mx + b, where:
- y = ln(T_final - T(t))
- x = t
- m = -1/τ (slope)
- b = ln(T_final - T_initial) (intercept)

Linear regression is used to find the slope and intercept, from which τ and the step
response magnitude can be calculated.

=head1 DEPENDENCIES

=over

Used for linear regression calculations.

=back

=head1 AUTHOR

Brett Gersekowski

=head1 SEE ALSO

L<PowerSupplyControl::Controller>, L<PowerSupplyControl::Math::PiecewiseLinear>

=cut

sub new {
  my ($class, %config) = @_;

  my $self = { resistance => $config{resistance}
             , regressionThreshold => $config{regressionThreshold} || 0.8 # Default to 0.8
             };

  bless $self, $class;

  return $self;
}

sub getRegressionThreshold {
  my $self = shift;
  my $threshold = $self->{regressionThreshold};

  if (@_) {
    $self->{regressionThreshold} = shift;
  }

  return $threshold;
}

sub _setupResponseParameters {
  my ($self, $data, $ylabel, $xlabel, $config) = @_;

  my $final   = defined($config->{final}) ? $config->{final} : $data->[-1]->{$ylabel};
  my $initial = defined($config->{initial}) ? $config->{initial} : $data->[0]->{$ylabel};

  my $step;
  my $direction;
  my $threshold;

  if ($final > $initial) {
    $step = $final - $initial;
    $direction = 1;
    $threshold = defined($config->{threshold}) ? $config->{threshold} : $initial + $step * $self->{regressionThreshold};
  } elsif ($final < $initial) {
    $step = $initial - $final;
    $direction = -1;
    $threshold = defined($config->{threshold}) ? $config->{threshold} : $initial - $step * $self->{regressionThreshold};
  } else {
    croak "Initial value ($initial) and final value ($final) cannot be the same";
  }

  return ($initial, $final, $step, $direction, $threshold);
}

sub fitCurve {
  my ($self, $data, $ylabel, $xlabel, %config) = @_;

  my ($initial, $final, $step, $direction, $threshold) = $self->_setupResponseParameters($data, $ylabel, $xlabel, \%config);

  # Regression sum variables
  my $xsum = 0;
  my $ysum = 0;
  my $x2sum = 0;
  my $xysum = 0;
  my $n = 0;

  # build up the regression sum variables
  for my $point (@$data) {
    my $y = $point->{$ylabel};
    # For rising response, stop at threshold; for falling, stop at threshold
    if (($direction == 1 && $y > $threshold) || ($direction == -1 && $y < $threshold)) {
      last;
    }

    my $x = $point->{$xlabel};
    my $logy = log($direction * ($final - $y));

    $xsum += $x;
    $ysum += $logy;
    $x2sum += $x * $x;
    $xysum += $x * $logy;
    $n++;
  }

  if ($n < 2) {
    croak "Not enough data points to perform regression";
  }

  # calculate the gradient and intercept of the regression line
  my $gradient = ($n * $xysum - $xsum * $ysum) / ($n * $x2sum - $xsum * $xsum);
  my $intercept = ($ysum - $gradient * $xsum) / $n;

  # calculate the time constant and step response magnitude
  my $tau = -1 / $gradient;

  my $result = { xsum => $xsum
               , ysum => $ysum
               , x2sum => $x2sum
               , xysum => $xysum
               , n => $n
               , gradient => $gradient
               , intercept => $intercept
               , tau => $tau
               , step => exp($intercept) * $direction
               , initial => $initial
               };
  
  # Use the step+initial for the final value - should be a better fit, I think...
  $result->{final} = $initial + $result->{step};

  if ($self->{resistance}) {
    $result->{capacitance} = $result->{tau} / $self->{resistance};
    $result->{resistance} = $self->{resistance};
  }

  return $result;
}

1; 