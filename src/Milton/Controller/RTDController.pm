package Milton::Controller::RTDController;

use strict;
use Milton::Math::PiecewiseLinear;
use base qw(Milton::Controller);
use Readonly;
use Carp qw(croak);
use Data::Dumper;
use Milton::DataLogger qw(get_namespace_debug_level);

use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_STATUS => 150;

Readonly my $ALPHA_CU => 0.00393;

=head1 NAME

Milton::Controller::RTDController - base class for controllers that use the heating element as an RTD to estimate temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Convert the temperature/resistance values into a piecewise linear estimator
  $self->{rt_estimator} = Milton::Math::PiecewiseLinear->new
          ->addHashPoints('resistance', 'temperature', @{$config->{calibration}->{temperatures}});

  if ($config->{'device'}) {
    $self->_initializeDevice($config->{'device'});
  }

  # Default maximum temperature rate of change in celsius per second
  $self->{'maximum-temperature-rate'} //= 30;

  return $self;
}

sub _initializeDevice {
  my ($self, $config) = @_;
  my $package = $config->{'package'};

  eval "use $package";

  if ($@) {
    croak "Failed to load package $package: $@";
  }

  my $device = undef;
  eval {
    $device = $package->new(logger => $self->{logger}, %$config);
  };
  # Ignore errors. Device assistance is optional. Warn the user and continue.
  if (!defined($device) || $@) {
    $self->warning("Failed to initialize device $package: $@\nContinuing without device assistance.");
    delete $self->{device};
    return;
  }

  $self->setDevice($device);
  $self->info('Connected to device '. $device->deviceName);

  $device->listenNow();

  return $device;
}

=head2 resetTemperatureCalibration($status)

Reset the calibration of this controller. This may be called during hotplate calibration if it is desired to ignore the old
calibration data and start fresh from some (hopefully) sane defaults.

=over

=item $flag

Defaults to true.

If true, calbration will be reset and auto-calibration will be disabled.
If false, auto-calibration will be enabled.

=cut

sub resetTemperatureCalibration {
  my ($self, $flag) = @_;

  $self->{rt_estimator} = Milton::Math::PiecewiseLinear->new;
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

  # Get the device temperature first, in case we're acout to bug out due to no current.
  if ($self->hasTemperatureDevice) {
    my ($hot, $cold) = $self->{device}->getTemperature;
    $status->{'device-temperature'} = $hot;
    if (defined $cold) {
      $status->{'device-ambient'} = $cold;
    }
  }

  my $resistance = $status->{resistance};
  if (!defined($resistance)) {
    # If there is insufficient current flowing and no resistance measurement, temperature cannot be estimated.
    return if ($status->{current} < $self->{interface}->getMeasurableCurrent);
    $resistance = $status->{voltage} / $status->{current};
    $status->{resistance} = $resistance;
  }

  # If the estimator is empty, give it some sane defaults assuming a copper heating element
  if ($est->length() == 0 && !$self->{reset}) {
    my $ambient = $self->getAmbient($status);
    $est->addNamedPoint($resistance, $ambient, 'ambient');
    $self->warning("Auto-adding calibration point at T=$ambient, R=$resistance (name: ambient)");
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
    $self->warning("Auto-adding calibration point at T=$t1, R=$r1 (name: interpolated)");
    $est->addNamedPoint($r1, $t1, 'interpolated');
  }

  my $temperature = $est->estimate($resistance);
  my $last_temp = $self->{'last-temperature'};
  if (defined $last_temp) {
    my $rate = abs($temperature - $last_temp) / $status->{period};

    if ($rate > $self->{'maximum-temperature-rate'}) {
      die "Temperature rate of change ($rate) exceeds maximum rate of $self->{'maximum-temperature-rate'}";
    }
  }
  $self->{'last-temperature'} = $temperature;
  $status->{temperature} = $temperature;
  $self->debug("status: ". Dumper($status)) if DEBUG_LEVEL >= DEBUG_STATUS;

  # If we have a predictor, use it now
  if (defined $self->{predictor}) {
    $self->{'predict-temperature'} = $self->{predictor}->predictTemperature($status);
  }

  return $temperature;
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

=head2 getTemperaturePoints

Get the list of temperature calibration points.

=cut

sub getTemperaturePoints {
  my ($self) = @_;
  return $self->{rt_estimator}->getPoints();
}

=head2 temperatureEstimatorLength()

Get the number of calibration points in the RTD estimator.

=cut

sub temperatureEstimatorLength {
  my ($self) = @_;  
  return $self->{rt_estimator}->length();
}

=head2 hasTemperatureDevice

Returns true if the controller has a temperature device available to measure
the temperature of the hotplate independent of the heating element RTD.

=cut

sub hasTemperatureDevice {
  my ($self) = @_;

  return defined $self->{device};
}

sub getDeviceTemperature {
  my ($self) = @_;

  if ($self->hasTemperatureDevice) {
    return $self->{device}->getTemperature;
  }

  return;
}

sub startDeviceListening {
  my ($self) = @_;

  if ($self->hasTemperatureDevice) {
    $self->{device}->startListening;
  }

  return;
}

sub shutdown {
  my ($self) = @_;

  if ($self->hasTemperatureDevice) {
    $self->info('Shutting down %s device', $self->{device}->deviceName);
    $self->{device}->stopListening;
    $self->{device}->shutdown;
  }
}

sub getDeviceName {
  my ($self) = @_;

  if ($self->hasTemperatureDevice) {
    return $self->{device}->deviceName;
  }

  return;
}

sub getDevice {
  my ($self) = @_;

  return $self->{device};
}

sub setDevice {
  my ($self, $device) = @_;

  $self->{device} = $device;
  if ($self->{logger}) {
    $device->setLogger($self->{logger});
  }
}

sub setLogger {
  my ($self, $logger) = @_;

  $self->SUPER::setLogger($logger);
  
  if ($self->{device}) {
    $self->{device}->setLogger($logger);
  }
}

1;
