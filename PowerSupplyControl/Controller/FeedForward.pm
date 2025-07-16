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
  croak "controller.calibration.thermal-resistance not specified." unless $config->{calibration}->{'thermal-resistance'};
  croak "controller.calibration.heat-capacity not specified." unless $config->{calibration}->{'heat-capacity'};

  $self->{'ttr-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new->addHashPoints(temperature => 'thermal-resistance', @{$config->{calibration}->{'thermal-resistance'}});
  $self->{'tch-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new->addHashPoints(temperature => 'heat-capacity', @{$config->{calibration}->{'heat-capacity'}});

  if (!exists $self->{power}->{maximum}) {
    my ($pmin, $pmax) = $interface->getPowerLimits();
    $self->{power}->{maximum} = $pmax;
  }

  $self->{'min-error'} //= 10;
  $self->{'predict-time-constant'} //= 20;

  return $self;
}

=head2 getRequiredPower($status, $target_temp)

Calculate the power required to achieve a certain hotplate temperature by the next sample period.

=cut

sub getRequiredPower {
  my ($self, $status) = @_;
  my $period = $status->{period};

  my ($temperature, $predict_alpha);
  if (exists $self->{'predict-temperature'}) {
    $temperature = $self->{'predict-temperature'};
    $predict_alpha = $self->{'predict-alpha'};
  } else {
    $temperature = $status->{temperature};
    $predict_alpha = $period / ($period + $self->{'predict-time-constant'});
    $self->{'predict-alpha'} = $predict_alpha;
  }
  $status->{'predict-alpha'} = $predict_alpha;
  $temperature = $predict_alpha * $temperature + (1 - $predict_alpha) * $status->{temperature};
  #print "predict-alpha: $predict_alpha, predict-temperature: $temperature, temperature: $status->{temperature}\n";

  my $delta_T = $status->{'then-temperature'} - $temperature;
  my $offset_T = $status->{'then-temperature'} - $status->{ambient};

  my $R = $self->getThermalResistance($status->{'then-temperature'});
  my $C = $self->getHeatCapacity($status->{'then-temperature'});
  $status->{rth} = $R;
  $status->{ch} = $C;
  
  my $error = $status->{'now-temperature'} - $temperature;
  $status->{error} = $error;

  $self->{'predict-temperature'} = $temperature;
  $status->{'predict-temperature'} = $temperature;

  my $pid_factor = $self->{'pid-factor'} // 0.3;
  my $kp = 1 / $R * $pid_factor;
  my $ki = $period * $kp / $R / $C * $pid_factor;

  my $anti_windup_factor = $status->{'anti-windup-factor'} // 0.15;
  my $pmax = $self->{power}->{maximum};
  my $max_error;
  if ($ki > 0) {
    $max_error = $pmax / $ki * $anti_windup_factor;
  } else {
    $max_error = 0;
  }

  my $err_sum = $self->{'error-sum'} // 0;
  if (abs($err_sum) < $max_error) {
    $err_sum += $error;
  }

  $self->{'error-sum'} = $err_sum;
  $status->{'error-sum'} = $err_sum;

  my $ff_power = $C*$delta_T/$period + $R*$offset_T;
  # Unfortunately we can't make the heat flow back out of the hotplate as electricity, so...
  if ($ff_power < 0) {
    $ff_power = 0;
  }
  my $p_power = $kp*$error;
  my $i_power = $ki*$err_sum;
  my $pid_power = $p_power + $i_power;
  my $power = $ff_power + $pid_power;
  $status->{'ff-power'} = $ff_power;
  $status->{'pid-power'} = $pid_power;
  $status->{'p-power'} = $p_power;
  $status->{'i-power'} = $i_power;
  $status->{'uf-power'} = $power;

  # Use the time-constant of the smoothing-time if that was what was provided
  if (!exists $self->{'smoothing'} && exists $self->{'smoothing-time'}) {
    $self->{'smoothing'} = 1 - ($period / ($period + $self->{'smoothing-time'}));
  }
  my $smoothing = $self->{'smoothing'} // 0.66;
  $power = (1 - $smoothing) * $power + $smoothing * $self->{'power-iir'};

  if ($error < $self->{'min-error'}) {
    $power = 0.1;
  } elsif ($power > $pmax) {
    $power = $pmax;
  }

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
  $self->{'ttr-estimator'}->addPoint($temperature, $thermal_resistance);
}

=head2 thermalResistanceEstimatorLength()

Get the number of thermal resistance calibration points in the thermal resistance estimator.

=cut

sub thermalResistanceEstimatorLength {
  my ($self) = @_;
  return $self->{'ttr-estimator'}->length();
}

=head2 getThermalResistance($temperature)

Get the thermal resistance at the given temperature.

=over

=item $temperature

The temperature at which to get the thermal resistance.

=cut

sub getThermalResistance {
  my ($self, $temperature) = @_;
  return $self->{'ttr-estimator'}->estimate($temperature);
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
  $self->{'tch-estimator'}->addPoint($temperature, $heat_capacity);
}

=head2 heatCapacityEstimatorLength()

Get the number of heat capacity calibration points in the heat capacity estimator.

=cut

sub heatCapacityEstimatorLength {
  my ($self) = @_;
  return $self->{'tch-estimator'}->length();
}

=head2 getHeatCapacity($temperature)

Get the effective heat capacity at the given temperature.

=cut

sub getHeatCapacity {
  my ($self, $temperature) = @_;
  return $self->{'tch-estimator'}->estimate($temperature);
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
