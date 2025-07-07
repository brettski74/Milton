package PowerSupplyControl::Controller::RTDController;

use strict;
use PowerSupplyControl::Math::PiecewiseLinear;
use base qw(PowerSupplyControl::Controller);
use Readonly;

Readonly my $ALPHA_CU => 0.00393;

=head1 NAME

PowerSupplyControl::Controller::RTDController - base class for controllers that use the heating element as an RTD to estimate temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Convert the temperature/resistance values into a piecewise linear estimator
  $self->{rt_estimator} = PowerSupplyControl::Math::PiecewiseLinear->new
          ->addHashPoints('resistance', 'temperature', @{$config->{'temperatures'}});

  return $self;
}

=head2 resetTemperatureCalibration($status)

Reset the calibration of this controller. This may be called during hotplate calibration if it is desired to ignore the old
calibration data and start fresh from some (hopefully) sane defaults.

=cut

sub resetTemperatureCalibration {
  my ($self, $flag) = @_;

  $self->{rt_estimator} = PowerSupplyControl::Math::PiecewiseLinear->new;
  $self->{reset} = $flag // 1;
}

=head2 getTemperature($status)

Get the current temperature of the hotplate based on it's latest measured resistance.

=over

=item $status

The current status of the hotplate as provided by the framework. It needs to contain the current voltage and current measurements.
From this, the resistance of the heating element will be calculated. This is then used to estimate the current temperature of the
hotplate.

On return, the calculated resistance and temperature values will be placed in the status hash and may be used elsewhere.

=item Return Value

Returns the estimated temperature of the hotplate in degrees celsius.

=back

=cut

sub getTemperature {
  my ($self, $status) = @_;
  my $est = $self->{rt_estimator};

  # If there is insufficient current flowing, temperature cannot be estimated.
  return if ($status->{current} < $self->{interface}->getMeasurableCurrent);

  my $resistance = $status->{resistance} // ($status->{voltage} / $status->{current});

  # If the estimator is empty, give it some sane defaults assuming a copper heating element
  if ($est->length() == 0 && !$self->{reset}) {
    my $ambient = $self->{ambient} || 20.0;
    $est->addPoint($resistance, $ambient);
  }
  
  # If the estimator has only one point, add a second point to make it a linear estimator
  if ($est->length() == 1) {
    my $r0 = $est->[0]->[0];
    my $t0 = $est->[0]->[1];
    my ($r1, $t1);

    if ($t0 == 20) {
      $t1 = 19;
      $r1 = $r0 * (1 - $ALPHA_CU);
    } else {
      # Back-calculate R0 for T0=20C
      $t1 = 20;
      $r1 = ($r0 / (1 + $ALPHA_CU * ($t0 - $t1)));
    }
    print "Auto-adding calibration point at T=$t1, R=$r1\n";
    $est->addPoint($r1, $t1);
  }

  my $temperature = $est->estimate($resistance);

  $status->{resistance} = $resistance;
  $status->{temperature} = $temperature;

  return $temperature;
}

=head2 setAmbient($temperature)

Set the current ambient temperature.

=over

=item $temperature

The current ambient temperature in degrees celsius.

=item Return Value

The previously set value of ambient temperature, if any.

=cut

sub setAmbient {
  my ($self, $temperature) = @_;
  my $ambient = $self->{ambient};
  $self->{ambient} = $temperature;
  return $ambient;
}

=head2 getAmbient()

Get the current ambient temperature.

=cut

sub getAmbient {
  my ($self) = @_;
  return $self->{ambient};
}

=head2 setTemperaturePoint($temperature, $resistance)

Set a temperature calibration point for the RTD estimator.

=over

=item $temperature

The measured temperature of the hotplate at this calibration point.

=item $resistance

The measured resistance of the hotplate at this calibration point.

=back

=cut

sub setTemperaturePoint {
  my ($self, $temperature, $resistance) = @_;
  $self->{rt_estimator}->addPoint($resistance, $temperature);
}

=head2 temperatureEstimatorLength()

Get the number of calibration points in the RTD estimator.

=cut

sub temperatureEstimatorLength {
  my ($self) = @_;  
  return $self->{rt_estimator}->length();
}

1;
