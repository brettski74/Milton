package HP::Interface;

=head1 SYNOPSIS

  my $interface = HP::Interface::DPS->new($config);

  my $status = $interface->poll;

  $interface->setPower($status, $constant_power);
  $interface->setVoltage($status, $constant_voltage);
  $interface->setCurrent($status, $constant_current);

  ...
  
=head1 DESCRIPTION

Interface definition for an interface with a power supply. 

=head1 CONSTRUCTOR

=head2 new($config)

Create a new interface object with the specified properties.

=back

=cut

sub new {
  my ($class, $config) = @_;

  bless $config, $class;

  return $config;
}

=head1 METHODS

=head2 poll

Poll the power supply and/or heating element for current status. The return value is a reference to a hash containing current status information. Subclasses may provide additional values, but they must provide the following as a bare minimum:

=over

=item voltage

The current voltage measured at the output of the power supply.

=item current

The current current measured at the output of the power supply.

=back

Note that this default implementation returns undef. You must use an appropriate subclass that supports your power supply and interface.

=cut

sub poll {
  return;
}

=head2 setVoltage($voltage)

Set the output voltage of the power supply. This usually involves setting the current setpoint to the maximum allowed and the voltage setpoint to the specified value.

=over

=item $voltage

The voltage required from the power supply measured in volts.

=back

=cut

sub setVoltage {
  return;
}

=head2 setCurrent($current)

Set the output current of the power supply as measured in amps. This usually involves setting the voltage setpoint to the maximum allowed and the current setpoint to the specified value.

=over

=item $current

The current required from the power supply measured in amps.

=back

=cut

sub setCurrent {
  return;
}

=head2 setPower($power, $resistance)

Set the output power of the power supply as measured in watts. This usually involves setting either the current or voltage output based on some known value of the load resistance.

The default implementation determines the required voltage for the requested power based on the load resistance and calls setVoltage with that value.

=over

=item $power

The power required from the power supply measured in watts.

=item $resistance

The current value of the load resistance.

=back

=cut

sub setPower {
  my ($self, $power, $resistance) = @_;

  my $voltage = sqrt($power * $resistance);

  return $self->setVoltage($voltage);
}

=head2 shutdown

Shut off the power to the hotplate and close the connection.

=cut

sub shutdown {
  return;
}

1;
