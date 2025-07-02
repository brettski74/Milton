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
No additional configuration parameters are required for bang-bang control.

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

  return $self;
}

sub getRequiredPower {
  my ($self, $status, $target_temp) = @_;

  my ($minPower, $maxPower) = $self->{interface}->getPowerLimits();

  if ($status->{temperature} < $target_temp) {
    return $maxPower;
  }

  return $minPower;
}

1;