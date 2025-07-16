package PowerSupplyControl::Controller;

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

=head2 getRequiredPower($status, $target_temp

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

1;
