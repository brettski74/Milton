package PowerSupplyControl::Interface;

=head1 SYNOPSIS

  my $interface = PowerSupplyControl::Interface::DPS->new($config);

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

=head1 DESTRUCTOR

=head2 DESTROY

The destructor for the interface. This is called when the interface object goes out
of scope. The default implementation ensures that the power supply is turned off and
the connection to the power supply is gracefully closed by calling:

    $self->on(0);
    $self->shutdown;A

if your implementation requires any additional processing beyond this, you should
override this method. It is strongly recommended that you call SUPER::DESTROY from
within your implementation.

=cut

sub DESTROY {
  my ($self) = @_;

  $self->on(0);
  $self->shutdown;
  return;
}

=head1 METHODS

=head2 poll([$status])

Poll the power supply and/or heating element for current status.

=over

=item $status

An optional parameter containing a reference to a hash to be used as the status
hash returned by this method. If provided, the interface must use this hash and
return it as the return value. The passed hash reference may or may not contain
existing data which may be overwritten by the interface. It is generally expected
that the interface will not alter data unrelated to its normal operation, so any
additional keys in the has will not have their values altered.

=item Return Value

A reference to a status hash. The exact contents of the hash are not completely 
specified here and different interface implementations may return additional data
as they see fit, but the following values must be returned as a minimum:

=over

=item voltage

The current voltage measured at the output of the power supply.

=item current

The current current measured at the output of the power supply.

=back

Note that this default implementation returns undef. You must use an appropriate
subclass that supports your power supply and interface.

=back

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

=head2 getMinimumCurrent

Get the minimum current required to measure the resistance of the hotplate. The default implementation returns 0.1 amps.

=over

=item Return Value

The minimum current required to measure the resistance of the hotplate.

=cut

sub getMinimumCurrent {
  return $self->{current}->{minimum} || 0.1;
}

=head2 getMeasurableCurrent

Get the minimum current where resistance can reasonably be measured.

=cut

sub getMeasurableCurrent {
  return $self->{current}->{measurable} || 0.1;
}

=head2 getCurrentLimits

Get the minimum and maximum current limits of the power supply.

=over

=item Return Value

A two element list containing the mimimum and maximum current limits configured for this interface.

=back

=cut

sub getCurrentLimits {
  my ($self) = @_;
  return ( $self->{current}->{minimum} || 0.1, $self->{current}->{maximum} || 10 );
}

=head2 getVoltageLimits

Get the minimum and maximum voltage limits of the power supply.

=over

=item Return Value


A two element list containing the mimimum and maximum voltage limits configured for this interface.

=back

=cut

sub getVoltageLimits {
  my ($self) = @_;
  return ( $self->{voltage}->{minimum} || 1, $self->{voltage}->{maximum} || 30 );
}

=head2 getPowerLimits

Get the minimum and maximum power limits of the power supply.

=over

=item Return Value

A two element list containing the mimimum and maximum power limits configured for this interface.

=back

=cut

sub getPowerLimits {
  my ($self) = @_;
  return ( $self->{power}->{minimum} || 0, $self->{power}->{maximum} || 120 );
}

=head2 shutdown

Shut off the power to the hotplate and close the connection.

=cut

sub shutdown {
  return;
}

=head2 resetCalibration

Reset the calibration of the power supply.

=cut

sub resetCalibration {
  return;
}

1;
