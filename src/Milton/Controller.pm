package Milton::Controller;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Milton::Math::PiecewiseLinear;
use Milton::Predictor;

=encoding utf8

=head1 NAME

Milton::Controller - Base class for hotplate temperature controllers

=head1 SYNOPSIS

  use Milton::Controller;
  
  # Create a controller with configuration
  my $controller = Milton::Controller->new($config, $interface);
  
  # Get current temperature
  my $temperature = $controller->getTemperature($status);
  
  # Calculate required power
  my $power = $controller->getRequiredPower($status);
  
  # Get required power with safety limits applied
  my $limited_power = $controller->getPowerLimited($status);

=head1 DESCRIPTION

C<Milton::Controller> is the base class for all hotplate temperature controllers in the Milton 
system. It defines the common interface and provides shared functionality for power limits, 
safety cutoffs, and predictor integration.

The controller's primary responsibility is managing the thermal behaviour of the hotplate
assembly and providing mechanisms to control temperature. This includes things like taking
temperature measurements, implementing safety limits to avoid problems due to excessive
temperatures, temperature control algorithms and with the assistance of prediction models,
understanding how temperature changes over time.

Note that there are also electrical limits that Milton applies, but these are the domain of the
interface classes, not the controller. The controller should perform calculations based on what's
happening in or required by the thermal system. Staying within the electrical capabilities of the
power supply is the interface object's responsibility.

=head1 SAFETY FEATURES

=head2 Power Limits

All controllers support temperature-dependent power limits to prevent excessive heating that could 
damage the hotplate, cause thermal fuse trips or worse. Power limits are specified as piecewise
linear mappings from temperature to maximum allowed power. They provide a gradual limit on power
to gracefully avoid exceeding safety thresholds. They are applied based on the heating element
temperature.

=over

=item * **Purpose**: Prevent thermal fuse trips, hotplate damage, fire and other non-fun events.

=item * **Configuration**: Temperature/power point mappings in controller configuration

=item * **Application**: Automatically limits power available to the hotplate based on current temperature.

=back

=head2 Cutoff Temperature

All controllers support a cutoff temperature feature that immediately reduces power to zero when 
the heating element temperature exceeds a safety threshold. This is a last resort option to prevent
exceeding safe operating temperatures for the hotplate assembly in the event that the control
algorithm and safety limits are insufficient.

=over

=item * **Purpose**: Emergency safety shutdown

=item * **Configuration**: Single temperature threshold in controller configuration

=item * **Application**: Immediate power reduction to virtual zero (actually minimum power) when threshold is exceeded

=back

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Creates a new controller instance with the specified configuration and interface.

=over

=item C<$config>

Configuration hash reference containing:

=over

=item C<limits>

Safety limits configuration:

=over

=item C<power-limits>

Array of temperature/power mappings for power limiting

=item C<cut-off-temperature>

Temperature threshold for emergency cutoff (°C)

=item C<ambient>

Default ambient temperature (°C, default: 25)

Note that this is the *default* ambient temperature. It is only applied if a better estimate of the
ambient temperature is not available. It's also used as a heuristic baseline to estimate the quality
of some ambient temperature estimates. See the L<Milton::Controller::getAmbient> method for more details.

=back

=item C<predictor>

Predictor configuration hash:

=over

=item C<package>

Predictor class name (e.g., 'BandedLPF', 'DoubleLPF')

Can be the fully-qualified package name or just the short name if it's in the C<Milton::Predictor> namespace.

=item Additional predictor-specific parameters

=back

=back

=item C<$interface>

Interface object for communicating with the power supply

=back

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
    # Use the pass-through predictor by default
    $self->{predictor} = Milton::Predictor->new;
  }

  # If the predictor needs the interface, provide it
  if ($self->{predictor}->can('setInterface')) {
    $self->{predictor}->setInterface($interface);
  }

  return $self;
}

=head1 METHODS

=head2 getTemperature($status)

Read currently available measurements of hotplate temperature. This generally includes the heating
element temperature but may also include the device-temperature reading if a temperature sensor device
is available.

=over

=item $status

Status hash containing current system measurements

=item Return Value

Current heating element temperature (°C) or undef if not available

=item Side Effects

Sets the C<temperature> key in the C<$status> hash to the current heating element temperature.
May also set the C<resistance> key in the C<$status> hash if not already present.
May also set the C<device-temperature> and C<device-ambient> keys in the C<$status> hash if not already present and a temperature sensor device is available.

=back

=cut

sub getTemperature {
  return;
}

=head2 setAnticipation($num_samples)

Sets the number of additional samples to look ahead when calculating the required power.

Not all controller support anticipation, but if it is supported by both the controller and the
command executing, this method tells the command how many additional samples to look ahead and
provide those values in the anticipate-temperature and anticipate period keys in the status
hash.

=over

=item C<$num_samples>

The number of additional samples to look ahead for controller anticipation. For example, the
command will likely already provide details of target temperature for 1 sample period ahead. If
anticipation is set to 3, then the command will also provide a target temperature for 4 sample
period in the future. To disable anticipation, set the number of samples to 0.

=back

=cut

sub setAnticipation {
  my ($self, $num_samples) = @_;

  $self->{anticipation} = $num_samples;
}

=head2 getAnticipation()

Returns the number of additional samples to look ahead when calculating the required power.

=over

=item Return Value

The number of additional samples to look ahead for controller anticipation. The return value
will always be true if anticipation is enabled and false if it is disabled.

=back

=cut

sub getAnticipation {
  my ($self) = @_;

  return $self->{anticipation};
}

=head2 description()

Returns a string describing the controller.

=cut

sub description {
  my ($self) = @_;

  return ref($self);
}

=head2 setLogger($logger)

Sets the logger for the controller and its predictor.

=over

=item C<$logger>

Logger object implementing the L<Milton::DataLogger> interface

=back

=cut

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

Calculates the power required to to send to the hotplate. This method is implemented by subclasses
to provide their specific control algorithms. Ideally, this should be the power required to achieve
a target temperature at a target time in the future - typically one sample period - although not all
control algorithms have the ability to do so. Ultimately, the method should return power levels that
over successive invocations will result in the hotplate temperature roughly following the temperatures
specified in the reflow profile, within some reasonable tolerance.

Most commands should avoid calling this method directly and should instead use the L<Milton::Controller::getPowerLimited>
method to get the power level with safety limits applied.

=over

=item $status

Status hash containing current system state and target temperature

=item Return Value

Required power level (W)

This method implements the control algorithm only. For the power level with thermal safety limits applied,
see the L<Milton::Controller::getPowerLimited> method.

=back

=cut

sub getRequiredPower {
  my ($self, $status) = @_;

  # Just return the value provided in the status - useful only for testing.
  return $status->{'set-power'} // $status->{power};
}

=head2 getPowerLimited($status)

Calculates the required power with safety limits applied. This method combines the control 
algorithm output with power limits and cutoff temperature safety features.

This method should be the preferred way to get the power level to send to the hotplate. It calls
the L<Milton::Controller::getRequiredPower> method internally to get the required power level to meet
the target temperature but then applies safety limits to the result. The return value should therefore
be the same as L<Milton::Controller::getRequiredPower> would have returned unless doing so may result
in exceeding a safety threshold.

=over

=item $status

Status hash containing current system state

=item Return Value

Power level (W) with safety limits applied

=back

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

=head2 hasTemperatureDevice()

Returns true if the controller has a temperature sensor device available, otherwise false.

=cut

sub hasTemperatureDevice {
  return;
}

=head2 getDeviceTemperature()

Returns the latest hotplate temperature measurement from the temperature sensor device.

=cut

sub getDeviceTemperature {
  return;
}

=head2 startDeviceListening()

Signal the temperature sensor device to start listening to temperature measurements. This usually
involves setting up an IO watcher to trigger when data is ready to read from the device.

=cut

sub startDeviceListening {
  return;
}

=head2 getDeviceName()

Returns the string providing the name or description of the temperature sensor device.

=cut

sub getDeviceName {
  return;
}

=head2 shutdown()

Shutdown the controller. This should be called when the controller is no longer needed.

=cut

sub shutdown {
  return;
}

=head2 enableLimits($flag)

Enables or disables power limiting.

=over

=item C<$flag>

True to enable limits, false to disable

=back

=cut

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

sub disableCutoff {
  my ($self) = @_;

  return $self->enableCutoff(0);
}

=head2 enableCutoff($flag)

Enables or disables cutoff temperature safety feature.

=over

=item C<$flag>

True to enable cutoff, false to disable

=back

=cut

sub enableCutoff {
  my ($self, $flag) = @_;

  if (@_ > 1 && !$flag) {
    $self->{'cutoff-disabled'} = 1;
  } else {
    delete $self->{'cutoff-disabled'};
  }
}

sub setCutoffTemperature {
  my ($self, $temperature) = @_;

  $self->{temperature}->{'cut-off-temperature'} = $temperature;
}

=head2 setPowerLimit($temperature, $power)

Sets a power limit for a specific temperature.

=over

=item C<$temperature>

Temperature at which the limit applies (°C)

=item C<$power>

Maximum allowed power at this temperature (W)

=back

=cut

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

=head2 getPredictor()

Returns the predictor object used by the controller.

=cut

sub getPredictor {
  my ($self) = @_;

  return $self->{predictor};
}

sub resetTemperatureCalibration {
  return;
}

=head1 USAGE EXAMPLES

=head2 Basic Controller Setup

  use Milton::Controller;
  use Milton::Interface::DPS;
  
  # Create interface
  my $interface = Milton::Interface::DPS->new($dps_config);
  
  # Create controller with safety limits
  my $config = {
    limits => {
      'power-limits' => [
        { temperature => 25,  power => 100 },
        { temperature => 100, power => 80 },
        { temperature => 200, power => 60 }
      ],
      'cut-off-temperature' => 250,
      ambient => 25
    },
    predictor => {
      package => 'BandedLPF',
      bands => [...]
    }
  };
  
  my $controller = Milton::Controller->new($config, $interface);

=head2 Safety Feature Configuration

  # Disable power limits for testing
  $controller->enableLimits(0);
  
  # Disable cutoff for high-temperature operation
  $controller->enableCutoff(0);
  
  # Add custom power limit
  $controller->setPowerLimit(150, 70);  # 70W max at 150°C

=head1 SUBCLASSES

=over

=item * L<Milton::Controller::RTDController> - Base class for RTD-based controllers

=item * L<Milton::Controller::BangBang> - Simple on/off control with optional modulation

=item * L<Milton::Controller::HybridPI> - PI control with optional feed-forward compensation

=back

=head1 SEE ALSO

=over

=item * L<Milton::Interface> - Power supply interface classes

=item * L<Milton::Predictor> - Temperature prediction classes

=item * L<Milton::DataLogger> - Logging interface

=back

=cut

=head1 AUTHOR

Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

1;
