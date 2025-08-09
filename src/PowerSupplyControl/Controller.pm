package PowerSupplyControl::Controller;

use Carp qw(croak);
use PowerSupplyControl::Math::PiecewiseLinear;
use PowerSupplyControl::Predictor;

=head1 NAME

PowerSupplyControl::Controller - Base class to define the interface for HP control modules.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

Create a new controller object with the specified properties.

This class merely defines the interface for controllers. It does not implement any functionality.

The sole purpose of a controller is to provide a method to get and set the temperature of the hotplate.
More direct control based on power, voltage or current can be achieved directly via the PowerSupplyControl::Interface object.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  $config->{interface} = $interface;

  bless $config, $class;

  if (exists $config->{calibration}->{'thermal-resistance'}) {
    my $ttr = $config->{calibration}->{'thermal-resistance'};
    $config->{'ttr-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new->addHashPoints(temperature => 'thermal-resistance', @$ttr);
  }

  if (exists $config->{calibration}->{'heat-capacity'}) {
    my $tch = $config->{calibration}->{'heat-capacity'};
    $config->{'tch-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new->addHashPoints(temperature => 'heat-capacity', @$tch);
  }

  if (exists $config->{predictor}) {
    eval "use $config->{predictor}->{package}";


    if ($@) {
      croak "Failed to load predictor $config->{predictor}->{package}: $@";
    }

    $config->{predictor} = $config->{predictor}->{package}->new(%{$config->{predictor}});
  } else {
    $config->{predictor} = PowerSupplyControl::Predictor->new;
  }

  return $config;
}

=head2 getTemperature($status)

Get the current temperature of the hotplate.

=over

=item $status

The current status of the hotplate.

=cut

sub getTemperature {
  return;
}

=head2 setLogger($logger)

Set the logger for the controller.

=cut

sub description {
  my ($self) = @_;

  return ref($self);
}

sub setLogger {
  my ($self, $logger) = @_;

  $self->{logger} = $logger;

  $self->info('Using Controller: '. $self->description);

  $self->{predictor}->setLogger($logger) if $self->{predictor};
}

=head2 predictTemperature($status)

Provide a prediction of the hotplate temperature based on the current status data. This usually
requires having some kind of measured temperature already in the status hash - most likely from
a previous call to getTemperature.

The purpose of this method is to predict the temperature of the surface of the hotplate, which is
what we're really interested in controlling. The temperature measurement is usually a temperature
measured based on the heating element resistance - basically using the heating element as an RTD.
Since this is also the source of heating, this temperature often leads and the temperature at the
surface of the hotplate lags behind. The default implementation of this method will use a simple
single pole low pass filter to predict a delay in heat getting to the hotplate. This filter can
be tuned to produce good results for a specific scenario - such as a solder reflow cycle. You can
tune the filter to the behaviour of your hotplate when unloaded using the calibrate command.
Alternatively, you can guess. For a 100mm square hotplate, values in the range of about 15-27
seconds work well. Since loaded hotplate will probably slow the response further, you should
probably tend toward the higher end of that range.

This delay filter can be configured by setting the 'predict-time-constant' parameter in the
controller configuration. Setting it to 0 disabled the delay filter.

=cut

sub predictTemperature {
  my ($self, $status) = @_;

  return $self->{predictor}->predictTemperature($status);
}

=head2 setPredictedTemperature($temperature)

Set the current temperature prediction. This is primarily used for testing to give the internal
IIR filter a known state.

=cut

sub setPredictedTemperature {
  my ($self, $temperature) = @_;

  $self->{predictor}->setPredictedTemperature($temperature);
}

=head2 getRequiredPower($status)

Calculate the power required to achieve a certain hotplate temperature by the next sample period.

=over

=item $status

The hash representing the current status of the hotplate.

=item $target_temp

The desired temperature to achieve on the hotplate by the next sample period.

=item Return Value

The power to be applied to the hotplate to achieve the target temperature.

=back

=cut

sub getRequiredPower {
  return;
}

=head2 setAmbient($temperature)

Set the current ambient temperature.

=over

=item $temperature

The current ambient temperature in degrees celsius.

=item Return Value

The previously set value of ambient temperature, if any.

=back

=cut

sub setAmbient {
  return;
}

=head2 getAmbient()

Get the current ambient temperature.

=cut

sub getAmbient {
  return;
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

  if (exists $self->{'ttr-estimator'}) {
    $self->{'ttr-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new;
  }

  $self->{'ttr-estimator'}->addPoint($temperature, $thermal_resistance);
}

=head2 thermalResistanceEstimatorLength()

Get the number of thermal resistance calibration points in the thermal resistance estimator.

=cut

sub thermalResistanceEstimatorLength {
  my ($self) = @_;

  if (exists $self->{'ttr-estimator'}) {
    return $self->{'ttr-estimator'}->length();
  }

  return 0;
}

=head2 getThermalResistance($temperature)

Get the thermal resistance at the given temperature.

=over

=item $temperature

The temperature at which to get the thermal resistance.

=cut

sub getThermalResistance {
  my ($self, $temperature) = @_;

  if (exists $self->{'ttr-estimator'}) {
    return $self->{'ttr-estimator'}->estimate($temperature);
  }

  return;
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

  if (exists $self->{'tch-estimator'}) {
    $self->{'tch-estimator'} = PowerSupplyControl::Math::PiecewiseLinear->new;
  }

  $self->{'tch-estimator'}->addPoint($temperature, $heat_capacity);
}

=head2 heatCapacityEstimatorLength()

Get the number of heat capacity calibration points in the heat capacity estimator.

=cut

sub heatCapacityEstimatorLength {
  my ($self) = @_;

  if (exists $self->{'tch-estimator'}) {
    return $self->{'tch-estimator'}->length();
  }

  return 0;
}

=head2 getHeatCapacity($temperature)

Get the effective heat capacity at the given temperature.

=cut

sub getHeatCapacity {
  my ($self, $temperature) = @_;

  if (exists $self->{'tch-estimator'}) {
    return $self->{'tch-estimator'}->estimate($temperature);
  }

  return;
}

sub hasTemperatureDevice {
  return;
}

sub getDeviceTemperature {
  return;
}

sub startDeviceListening {
  return;
}

sub getDeviceName {
  return;
}

sub shutdown {
  return;
}

sub disableSafety {
  return;
}

sub setCutoffTemperature {
  my ($self, $temperature) = @_;

  $self->{'cut-off-temperature'} = $temperature;
}

sub setPowerLimit {
  return;
}

sub info {
  my ($self, $message) = @_;
  if ($self->{logger}) {
    $self->{logger}->info($message);
  }
}

sub warning {
  my ($self, $message) = @_;
  if ($self->{logger}) {
    $self->{logger}->warning($message);
  }
}

sub debug {
  my ($self, $level, $message) = @_;
  if ($self->{logger}) {
    $self->{logger}->debug($level, $message);
  }
}

sub getPredictor {
  my ($self) = @_;

  return $self->{predictor};
}

1;
