package PowerSupplyControl::Math::SteadyStateDetector;

use strict;
use warnings qw(all -uninitialized);

use Carp;

=head1 NAME

PowerSupplyControl::Math::SteadyStateDetector - Detect steady state conditions using IIR filtering and hysteresis

=head1 SYNOPSIS

  my $detector = PowerSupplyControl::Math::SteadyStateDetector->new(
    smoothing => 0.9,
    threshold => 0.0001,
    samples => 10,
    reset => 0.00015
  );

  my $is_steady = $detector->check($new_measurement);

=head1 DESCRIPTION

This class implements steady state detection using an IIR (Infinite Impulse Response) low-pass filter
combined with sample counting and hysteresis. It's designed to detect when a system has reached
a stable operating condition by monitoring the rate of change of a measured value.

The detection algorithm works as follows:

1. Calculate the delta between current and previous values
2. Apply an IIR low-pass filter to smooth the delta values
3. Count consecutive samples where the filtered delta is below the threshold
4. Reset the count if the filtered delta exceeds the reset threshold (hysteresis)
5. Declare steady state when the count reaches the required number of samples

=head1 CONSTRUCTOR

=head2 new(%params)

Create a new SteadyStateDetector instance.

=over

=item smoothing

The smoothing factor for the IIR low-pass filter (default: 0.9). Must be greater than 0 and less than 1.
Values closer to 1 result in slower response but more stable detection.

=item threshold

The threshold below which the system is considered to be approaching steady state (default: 0.0001).
This is the maximum allowed rate of change for steady state detection.

=item samples

The number of consecutive samples that must meet the steady state criteria (default: 10).
Higher values provide more confidence but slower detection.

=item reset

The threshold above which we reset the steady state sample count (default: 1.5 * threshold).
This provides hysteresis to prevent oscillation around the threshold.

=back

=cut

sub new {
  my ($class, %params) = @_;

  # Set defaults
  my $smoothing = $params{smoothing} // 0.9;
  my $threshold = $params{threshold} // 0.0001;
  my $samples = $params{samples} // 10;
  my $reset = $params{reset} // ($threshold * 1.5);

  # Validate parameters
  croak "smoothing must be greater than 0 and less than 1" if $smoothing <= 0 || $smoothing >= 1;
  croak "threshold must be positive" if $threshold <= 0;
  croak "samples must be at least 1" if $samples < 1;
  croak "reset must be greater than threshold" if $reset <= $threshold;

  my $self = {
    smoothing => $smoothing,
    threshold => $threshold,
    samples => $samples,
    reset => $reset,
    'filtered-delta' => undef,
    count => 0,
    previous_measurement => undef
  };

  bless $self, $class;
  return $self;
}

=head1 METHODS

=head2 check($measurement)

Check if the system has reached steady state based on the new measurement.

=over

=item $measurement

The current measured value.

=back

Returns true if steady state has been detected, false otherwise.

=cut

sub check {
  my ($self, $measurement) = @_;

  # If this is the first measurement, just store it and return false
  if (!defined $self->{previous_measurement}) {
    $self->{previous_measurement} = $measurement;
    return 0;
  }

  # Calculate delta
  my $delta = $measurement - $self->{previous_measurement};
  $self->{last_delta} = $delta;

  # Apply IIR low-pass filter
  if (defined $self->{'filtered-delta'}) {
    $self->{'filtered-delta'} = $self->{smoothing} * $self->{'filtered-delta'} + 
                             (1 - $self->{smoothing}) * $delta;
  } else {
    $self->{'filtered-delta'} = $delta;
  }

  # Check steady state criteria
  if (abs($self->{'filtered-delta'}) < $self->{threshold}) {
    $self->{count}++;
  } elsif (abs($self->{'filtered-delta'}) < $self->{reset}) {
    if ($self->{count} > 0) {
      $self->{count}++;
    }
  } else {
    $self->{count} = 0;
  }

  # Update previous measurement
  $self->{previous_measurement} = $measurement;

  return if $self->{count} < $self->{samples};
  return 1;
}

=head2 isSteady()

Check if the system is currently in steady state without updating internal state.

Returns true if steady state has been detected, false otherwise.

=cut

sub isSteady {
  my ($self) = @_;

  return if $self->{count} < $self->{samples};
  return 1;
}

=head2 reset()

Reset the detector state. This clears the filtered delta, steady state count,
and previous measurement, effectively starting fresh detection.

=cut

sub reset {
  my ($self) = @_;

  $self->{'filtered-delta'} = undef;
  $self->{count} = 0;
  $self->{previous_measurement} = undef;
  $self->{last_delta} = undef;

  return $self;
}

=head2 getState()

Get the current state of the detector.

Returns a hash reference containing:
- 'filtered-delta': The current filtered delta value
- count: The current count of steady state samples
- previous_measurement: The previous measurement value
- last_delta: The last raw delta value

=cut

sub getState {
  my ($self) = @_;

  return {
    'filtered-delta' => $self->{'filtered-delta'},
    count => $self->{count},
    previous_measurement => $self->{previous_measurement},
    last_delta => $self->{last_delta}
  };
}

=head2 getCount

Get the current count of steady state samples.

=cut

sub getCount {
  my ($self) = @_;

  return $self->{count};
}

=head2 getParameters()

Get the current parameters of the detector.

Returns a hash reference containing:
- smoothing: The IIR filter smoothing factor
- threshold: The steady state threshold
- samples: The required number of samples
- reset: The reset threshold

=cut

sub getParameters {
  my ($self) = @_;

  return {
    smoothing => $self->{smoothing},
    threshold => $self->{threshold},
    samples => $self->{samples},
    reset => $self->{reset}
  };
}

1; 