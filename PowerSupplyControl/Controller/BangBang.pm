package PowerSupplyControl::Controller::BangBang;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Controller::RTDController);

=head1 NAME

PowerSupplyControl::Controller::BangBang - Bang-bang controller for hotplate temperature control

=head1 SYNOPSIS

    use PowerSupplyControl::Controller::BangBang;
    
    my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);
    my $power = $controller->getRequiredPower($status, $target_temp);

=head1 DESCRIPTION

PowerSupplyControl::Controller::BangBang implements a simple bang-bang (on/off) control strategy
for hotplate temperature control. This controller switches between maximum and
minimum power output based on whether the current temperature is below or above
the target temperature.

=head1 THEORY

Bang-bang control is the simplest form of feedback control. The controller has
only two states:
- B<ON>: Output maximum power when temperature is below target
- B<OFF>: Output minimum power when temperature is at or above target

This creates a simple hysteresis loop where the temperature oscillates around
the target value. The amplitude of oscillation depends on the thermal inertia
of the system and the difference between maximum and minimum power levels.

=head2 Advantages
- Simple to implement and understand
- No tuning parameters required
- Robust and reliable
- Fast response to large temperature deviations

=head2 Disadvantages
- Continuous oscillation around setpoint
- No fine control near the target temperature
- May cause excessive wear on heating elements
- Higher energy consumption due to overshooting

=head1 INHERITANCE

This class inherits from L<PowerSupplyControl::Controller::RTDController>, which provides:
- Temperature conversion from RTD resistance values
- Interface management for power supply communication
- Configuration handling

=head1 METHODS

=head2 new($config, $interface)

Constructor for the bang-bang controller.

=over 4

=item * C<$config> - Configuration hash reference containing controller parameters

=item * C<$interface> - Interface object for communicating with the power supply

=back

Returns a new PowerSupplyControl::Controller::BangBang instance.

=head2 getRequiredPower($status, $target_temp)

Calculates the required power output using bang-bang control logic.

=over 4

=item * C<$status> - Hash reference containing current system status
  - C<temperature> - Current temperature in degrees Celsius

=item * C<$target_temp> - Target temperature in degrees Celsius

=back

Returns the power level to apply:
- Maximum power if current temperature < target temperature
- Minimum power if current temperature >= target temperature

=head1 USAGE EXAMPLE

    use PowerSupplyControl::Controller::BangBang;
    use PowerSupplyControl::Interface::DPS;
    
    # Create interface
    my $interface = PowerSupplyControl::Interface::DPS->new($dps_config);
    
    # Create controller
    my $controller = PowerSupplyControl::Controller::BangBang->new($config, $interface);
    
    # Control loop
    while ($running) {
        my $status = $interface->getStatus();
        my $target_temp = 100.0;  # 100°C target
        
        my $power = $controller->getRequiredPower($status, $target_temp);
        $interface->setPower($power);
        
        sleep(1);  # Control update rate
    }

=head1 CONFIGURATION

The controller inherits configuration from L<PowerSupplyControl::Controller::RTDController>.
No additional configuration parameters are required for bang-bang control. Bang-bang control
is one of the simplest control schemes. The controller varies between on and off states based
on whether the hotplate temperature is above the target temperature or not. Because we need
some current flowing to measure the resistance and derive the temperature, the off state is
actually a minimum power state, but otherwise the controller is very simple and can be used
with minimal or even no calibration. On the down side, the controller is less accurate, will
produce a temperature curve that oscillates around the target temperature and may cause
greater wear on the hotplate. For a smoother temperature, you can use a feed-forward or PID
controller, but both of these require much more calibration and tuning to work well.

While this controller can be used with no calibration or tuning, the following options can
be used to improve the performance of the controller.

=head2 Resistance-Temperature Mapping

The controller can use a resistance-temperature mapping to more accurately derive the temperature
of the hotplate. Note that "accurately" can be a very subjective term when measuring the
temperature of something like a hotplate. The construction of the hotplate assembly, the
the placement of the sensor relative to the working surface and other factors can affect how
well the measured temperature matches the temperature of the working surface of the hotplate
or the current hotplate load (ie. your PCB being reflowed).

This controller measures the temperature of the hotplate using the heating element itself.
The heating element has very low thermal inertia, which means that its temperature varies
relatively quickly in response to changes in power. It takes time for this heat to be soaked
up by the surrounding materials such as the FR4 substrate, a heat spreader if used and the 
hotplate load. As a result, the temperature measured at the surface of the hotplate may be 
lower than that of the heating element. While temperature is varying slowly - which it the
case for most of the reflow cycle - this temperature offset should be relatively small but
will vary with temperature. Calibrating the hotplate temperature by measuring the temperature
of the working surface of the hotplate at several temperatures may allow better control of
the temperature subjected to the hotplate load. You can produce a resistance-temperature
mapping using the rtcal or rampcal commands. These produce a separate configuration file
that you can include in your controller configuration.

Note that this behaviour is inherited from the L<PowerSupplyControl::Controller::RTDController>
base class, so it works the same way for all RTD-based controllers.

=head2 Power-Temperature Mappings

Bang-bang control can produce large temperature overshoots - especially at lower temperatures.
This is due to the use of maximum output power in the on state. This effect can be mitigated
by providing a power-temperature mapping that tells the controller to use different power
levels at different temperatures. It still switches between on and off states, but the power
level used in the on state varies based on the target temperature of the hotplate.

There is currently no calibration process for this, so you'll have to wing it a bit. As a
general guideline for a 100mm square hotplate, you probably don't want to use less than 20W
of heating at room temperature and you probably want to aim for about 100W at 200 celsius.

=head2 Configuration Attributes

=over

=item power-levels

An array of temperature/power mappings. The controller will interpolate between these points
to derive a power level to use for the on state of the controller.

=over

=item temperature

The temperature at which a particualr power level should apply for the on state.

=item power

The power in watts that will apply at the corresponding temperature.

=back

=item temperatures

=pver

=item resistance

The resistance of the heating element at a given temperature.

=item temperature

The temperature at which the heating element should be at the corresponding resistance.

=back

=back

=head1 SEE ALSO

=over 4

=item * L<PowerSupplyControl::Controller::RTDController> - Base class for RTD-based controllers

=item * L<PowerSupplyControl::Controller::FeedForward> - Alternative controller with feed-forward compensation

=item * L<PowerSupplyControl::Controller> - Controller base class

=back

=head1 AUTHOR

Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski. All rights reserved.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  my ($minPower, $maxPower) = $interface->getPowerLimits();

  if (defined $config->{'power-levels'}) {
    $self->{'on-power'} = PowerSupplyControl::Math::PiecewiseLinear->new
            ->addHashPoints('temperature', 'power', @{$config->{'power-levels'}});
  } else {
    $self->{'on-power'} = PowerSupplyControl::Math::PiecewiseLinear->new(20, $maxPower);
  }

  $self->{'min-power'} = $minPower;

  return $self;
}

sub getRequiredPower {
  my ($self, $status, $target_temp) = @_;

  if ($status->{temperature} < $target_temp) {
    return $self->{'on-power'}->estimate($target_temp);
  }

  return $self->{'min-power'};
}

1;