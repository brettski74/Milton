package PowerSupplyControl::Controller::FeedForward;

use strict;
use Carp qw(croak);
use base qw(PowerSupplyControl::Controller::RTDController);
use Statistics::Regression;
use PowerSupplyControl::Math::ThermalModel;

=head1 NAME

PowerSupplyControl::Controller::FeedForward - Implements a FeedForward controller that uses a thermal model to predict the power required to reach the next target temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Create a new feed forward controller instance.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Verify mandatory parameters
  croak "PowerSupplyControl::resistance not specified." unless $config->{resistance};
  croak "capacity not specified." unless $config->{capacity};

  # Set defaults if required
  $self->{ambient} = $config->{ambient} || 20.0;

  # Create the regression model
  $self->{regression} = Statistics::Regression->new('Feed-forward Regression', [ 'power', 'rel_temp' ]);

  # Create the thermal model
  $self->{model} = PowerSupplyControl::Math::ThermalModel->new($self);

  # How many samples until we re-evaluate kp and kt?
  $self->{countdown} = $self->{'initial-regression-samples'} || $self->{'regression-samples'} || 10;

  # IIR filter coefficient for smoothing the power output
  $self->{alpha} = $self->{alpha} || 0.3;

  # Keep a log of the status every sample period
  $self->{log} = [];

  return $self;
}

=head2 getRequiredPower($status, $target_temp)

Calculate the power required to achieve a certain hotplate temperature by the next sample period.

=cut

sub getRequiredPower {
  my ($self, $status, $target_temp) = @_;

  # Set the power to achieve the target temperature
  my $power = $self->{model}->estimatePower($status, $target_temp);
  $power = $self->_filterOutputPower($power);

  return $power;
}

sub _filterOutputPower {
  my ($self, $power) = @_;

  if (exists $self->{power_iir}) {
    $power = $self->{alpha} * $power + (1 - $self->{alpha}) * $self->{power_iir};
  }

  $self->{power_iir} = $power;

  return $power;
}

sub _logStatus {
  my ($self, $status) = @_;

  if (@{$self->{log}}) {
    my $last = $self->{log}[-1];
    my $delta_T = $status->{temperature} - $last->{temperature};
    $last->{'delta-T'} = $delta_T;
    $self->{regression}->addPoint($delta_T, $last);
    $self->{countdown}--;

    if ($self->{countdown} <= 0) {
      my ($kp, $kt) = $self->{regression}->theta();
      $self->{model}->setKp($kp);
      $self->{model}->setKt($kt);
      $self->{countdown} = $self->{'regression-samples'} || 20;
    }
  }

  push @{$self->{log}}, $status;


}

=head2 setThermalResistancePoint($temperature, $thermal_resistance)

Set a thermal resistance calibration point for the RTD estimator.

=over

=item $temperature

The temperature at which the thermal resistance was measured.

=item $thermal_resistance

The effective thermal resistance at the given temperature.

=back

=cut

sub setThermalResistancePoint {
  my ($self, $temperature, $thermal_resistance) = @_;
  $self->{ttr_estimator}->addPoint($temperature, $thermal_resistance);
}

=head2 thermalResistanceEstimatorLength()

Get the number of thermal resistance calibration points in the thermal resistance estimator.

=cut

sub thermalResistanceEstimatorLength {
  my ($self) = @_;
  return $self->{ttr_estimator}->length();
}

=head2 getThermalResistance($temperature)

Get the thermal resistance at the given temperature.

=over

=item $temperature

The temperature at which to get the thermal resistance.

=cut

sub getThermalResistance {
  my ($self, $temperature) = @_;
  return $self->{ttr_estimator}->estimate($temperature);
}

=head2 setHeatCapacityPoint($temperature, $heat_capacity)

Set a heat capacity calibration point for the RTD estimator.

=over

=item $temperature

The temperature at which the heat capacity was measured.

=item $heat_capacity

The effective heat capacity at the given temperature.

=back

=cut

sub setHeatCapacityPoint {
  my ($self, $temperature, $heat_capacity) = @_;
  $self->{tch_estimator}->addPoint($temperature, $heat_capacity);
}

=head2 heatCapacityEstimatorLength()

Get the number of heat capacity calibration points in the heat capacity estimator.

=cut

sub heatCapacityEstimatorLength {
  my ($self) = @_;
  return $self->{tch_estimator}->length();
}

=head2 getHeatCapacity($temperature)

Get the effective heat capacity at the given temperature.

=cut

sub getHeatCapacity {
  my ($self, $temperature) = @_;
  return $self->{tch_estimator}->estimate($temperature);
}

=head2 getThermalTimeConstant($temperature)

Get the effective thermal time constant at the given temperature. This is the product of the thermal resistance and the heat capacity.

=over

=item $temperature

The temperature at which to get the effective thermal time constant.

=cut

sub getThermalTimeConstant {
  my ($self, $temperature) = @_;

  return $self->getThermalResistance($temperature) * $self->getHeatCapacity($temperature);
}

1;
