package Milton::Controller;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Milton::Math::PiecewiseLinear;
use Milton::Predictor;

=head1 NAME

Milton::Controller - Base class to define the interface for HP control modules.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

Create a new controller object with the specified properties.

This class merely defines the interface for controllers. It does not implement any functionality.

The sole purpose of a controller is to provide a method to get and set the temperature of the hotplate.
More direct control based on power, voltage or current can be achieved directly via the Milton::Interface object.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  $config->{interface} = $interface;

  my $self = bless $config, $class;

  my $limits = $config->{limits};
  if ($limits && exists $limits->{'power-limits'}) {
    foreach my $point (@{$limits->{'power-limits'}}) {
      $self->setPowerLimit($point->{temperature}, $point->{power});
    }
  }

  if (exists $config->{predictor}) {
    my $package = $config->{predictor}->{package};

    if (!defined $package) {
      croak "Predictor package not defined! Cannot create predictor.";
    }

    eval "use $package";

    if ($@) {
      if ($package !~ /^Milton::Predictor::/) {
        $package = "Milton::Predictor::$package";
        my $error = $@;

        # Try again with the namespace prefix added
        eval "use $package";

        if ($@) {
          croak "Failed to load predictor package $config->{predictor}->{package}: $error\nFailed to load predictor package $package: $@";
        }
      }
    }

    $self->{predictor} = $package->new(%{$config->{predictor}});
  } else {
    $self->{predictor} = Milton::Predictor->new;
  }

  # If the controller needs the interface, provide it
  if ($self->{predictor}->can('setInterface')) {
    $self->{predictor}->setInterface($interface);
  }

  return $self;
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

=head2 getAmbient($status)

Provide a standard way to get the ambient temperature from multiple potential sources. 

If the ambient temperature is already set in the $status hash (eg. from command line, previous
call, etc) use that.  Otherwise, take the minimum of temperature, device-temperature and
device-ambient. Compare that to the default ambient temperature set in the controller
configuration (or 25 celsius if not set).  If the minimum is within +/- 5 celsius of the
default, use the minimum. If not, assume we're starting hot and use the default.

If the ambient temperature is not set in the $status hash, it will be after calling this method.

=over

=item $status

A hash of data values representing the current state of the hotplate and power supply.

=item Return Value

The ambient temperature in degrees celsius.

=back

=cut
  
sub getAmbient {
  my ($self, $status) = @_;
  my $ambient = $status->{ambient};
  $self->debug(10, "getAmbient: ambient: $ambient");

  if (!defined $ambient) {
    my $default = $self->{limits}->{ambient} // 25;

    my $temperature = $status->{temperature};
    my $device_temperature = $status->{'device-temperature'};
    my $device_ambient = $status->{'device-ambient'};
    $self->debug(10, "default: $default, ambient: $ambient, device-temp: $device_temperature, device-ambient: $device_ambient");

    # If we have a temperature device but no device temperature, then maybe we need to poll it
    if (!defined($device_temperature) && defined($self->hasTemperatureDevice)) {
      ($device_temperature, $device_ambient) = $self->getDeviceTemperature;
      $self->debug(10, "Getting device temperature: device-temp: $device_temperature, device-ambient: $device_ambient");
    }

    $ambient = $device_ambient;

    if (defined($device_temperature) && $device_temperature < ($default+5) && (!defined($ambient) || $device_temperature < $ambient)) {
      $ambient = $device_temperature;
    }

    if (!defined($ambient) && defined($temperature) && $temperature < ($default+5)) {
      $ambient = $temperature;
    }

    if (!defined($ambient)) {
      $ambient = $default;
    }

    $self->info(sprintf('Ambient temperature: %.1f', $ambient));
    $status->{ambient} = $ambient;
  }

  return $ambient;
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
  my ($self, $status) = @_;

  # Just return the value provided in the status - useful only for testing.
  return $status->{'set-power'} // $status->{power};
}

=head2 getPowerLimited($power)

Get the required power, but with safe limits applied based on the safety limits specified in the
controller configuration.

=cut

sub getPowerLimited {
  my ($self, $status) = @_;

  my $power = $self->getRequiredPower($status);
  my $temperature = $status->{temperature};
  my $no_limits = $self->{'limits-disabled'};
  my $no_cutoff = $self->{'cutoff-disabled'};

  if (!$no_cutoff && defined $temperature) {
    my $cutoff = $self->{limits}->{'cut-off-temperature'};

    if (defined $cutoff && $temperature >= $cutoff) {
      # Set it to zero and let the interface deal with minimum power settings
      return 0;
    }

    if (!$no_limits && exists $self->{'power-limits'}) {
      my $limit = $self->{'power-limits'}->estimate($temperature);
      return $limit if $power > $limit;
    }
  }

  return $power;
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

sub enableLimits {
  my ($self, $flag) = @_;

  if (@_ > 1 && !$flag) {
    $self->{'limits-disabled'} = 1;
  } else {
    delete $self->{'limits-disabled'};
  }
}

sub disableLimits {
  my ($self) = @_;

  return $self->enableLimits(0);
}

sub setCutoffTemperature {
  my ($self, $temperature) = @_;

  $self->{temperature}->{'cut-off-temperature'} = $temperature;
}

sub setPowerLimit {
  my ($self, $temperature, $power) = @_;

  if (!exists $self->{'power-limits'}) {
    $self->{'power-limits'} = Milton::Math::PiecewiseLinear->new;
  }

  $self->{'power-limits'}->addPoint($temperature, $power);
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

sub resetTemperatureCalibration {
  return;
}

1;
