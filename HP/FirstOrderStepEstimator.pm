package HP::FirstOrderStepEstimator;

use strict;
use warnings qw(all -uninitialized);
use Statistics::LineFit;

=head1 NAME

HP::FirstOrderStepEstimator - First-order step response estimator for electrical/thermal systems

=head1 SYNOPSIS

    use HP::FirstOrderStepEstimator;
    
    # Create estimator for a thermal system
    my $estimator = HP::FirstOrderStepEstimator->new(
        initial => 25.0,      # Initial value (eg. temperature, voltage, etc) (°C)
        final   => 100.0,     # Final value (eg. temperature, voltage, etc) (°C)
        resistance => 10.0    # Thermal resistance (°C/W) or electrical resistance (Ω)
    );
    
    # Fit data to estimate time constant and step response
    $estimator->setData($data_points, 'temperature', 'time');
    
    # Access estimated parameters
    my $tau = $estimator->{tau};           # Time constant (seconds)
    my $step = $estimator->{step};         # Step response magnitude
    my $capacitance = $estimator->{capacitance}; # Thermal capacitance (J/°C)

=head1 DESCRIPTION

HP::FirstOrderStepEstimator implements a first-order step response estimator for thermal systems.
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

=head2 setData($data, $ylabel, $xlabel)

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

After calling setData(), the following properties are available:

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
    my $estimator = HP::FirstOrderStepEstimator->new(
        initial => 25.0,
        final   => 100.0,
        resistance => 5.0
    );
    
    # Fit the data
    $estimator->setData($data, 'temperature', 'time');
    
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

=item Statistics::LineFit

Used for linear regression calculations.

=back

=head1 AUTHOR

HP Controller Development Team

=head1 SEE ALSO

L<HP::Controller>, L<HP::PiecewiseLinear>

=cut

sub new {
  my ($class, $initial, $final, $resistance) = @_;

  my $self = { initial => $initial, final => $final, resistance => $resistance };

  bless $self, $class;

  return $self;
}

sub setData {
  my ($self, $data, $ylabel, $xlabel) = @_;
  my $xdata = [];
  my $ydata = [];

  my $initial = $self->{initial};
  my $final   = $self->{final};
  my $direction = ($final > $initial) ? 1 : -1;
  my $threshold = $initial + 0.632 * ($final - $initial);

  for my $point (@$data) {
    my $y = $point->{$ylabel};
    # For rising response, stop at threshold; for falling, stop at threshold
    if (($direction == 1 && $y > $threshold) || ($direction == -1 && $y < $threshold)) {
      last;
    }
    push @$xdata, $point->{$xlabel};
    push @$ydata, log($final - $y);
  }

  my $line = Statistics::LineFit->new;
  $line->setData($xdata, $ydata);
  my ($intercept, $slope) = $line->coefficients;

  $self->{tau} = -1 / $slope;
  $self->{step} = exp($intercept);

  if ($self->{resistance}) {
    $self->{capacitance} = $self->{tau} / $self->{resistance};
  }

  return $self;
}

1;