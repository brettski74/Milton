package PowerSupplyControl::Interface;

use strict;
use warnings qw(all -uninitialized);

use Carp qw(croak);

use PowerSupplyControl::Math::PiecewiseLinear;

=head1 SYNOPSIS

  my $interface = PowerSupplyControl::Interface::DPS->new($config);

  my $status = $interface->poll;

  $interface->setPower($status, $constant_power);
  $interface->setVoltage($status, $constant_voltage);
  $interface->setCurrent($status, $constant_current);

  ...
  
=head1 DESCRIPTION

Interface definition for an interface with a power supply. This is the base class
that defines the public interface and the interface that needs to implemented in
subclasses that provide the integration with different power supplies. The public
interface provides methods to set voltage, current and power and to get the current

If you're using this interface object to do stuff, you should use the public methods
(ie. the ones without an underscore prefix) and not the private methods which are
used to implement the underlying interface.

If you're implementing a new interface, you probably only need to implement the
following methods:

=over

_connect
_disconnect
on
_poll
_setCurrent
_setVoltage

=back

=head1 CONSTRUCTOR

=head2 new($config)

Create a new interface object with the specified properties. Check the exact subclass
that you're using the understand the exact parameters that are required to connect to
your power supply.

=back

=cut

sub new {
  my ($class, $config) = @_;

  bless $config, $class;

  $config->_buildCalibration;

  my ($vset, $iset, $on, $vout, $iout) = $config->_connect;

  # Store the raw values as reported by the power supply.
  $config->{raw} = { vset => $vset
                   , iset => $iset
                   , on => $on
                   , vout => $vout
                   , iout => $iout
                   };

  # Store the cooked values after calibration adjustments.
  my $cooked = { on => $on };
  if ($self->{'voltage-setpoint'}) {
    $cooked->{vset} = $self->{'voltage-setpoint'}->estimate($vset);
  } else {
    $cooked->{vset} = $vset;
  }
  if ($self->{'current-setpoint'}) {
    $cooked->{iset} = $self->{'current-setpoint'}->estimate($iset);
  } else {
    $cooked->{iset} = $iset;
  }
  if ($self->{'voltage-output'}) {
    $cooked->{vout} = $self->{'voltage-output'}->estimate($vout);
  } else {
    $cooked->{vout} = $vout;
  }
  if ($self->{'current-output'}) {
    $cooked->{iout} = $self->{'current-output'}->estimate($iout);
  } else {
    $cooked->{iout} = $iout;
  }

  $config->{cooked} = $cooked;

  return $config;
}


=head1 DESTRUCTOR

=head2 DESTROY

The destructor for the interface. This is called when the interface object goes out
of scope. The default implementation ensures that the power supply is turned off and
the connection to the power supply is gracefully closed by calling:

    $self->on(0);
    $self->_disconnect;

if your implementation requires any additional processing beyond this, you should
override this method. It is strongly recommended that you call SUPER::DESTROY from
within your implementation.

=cut

sub DESTROY {
  my ($self) = @_;

  $self->on(0);
  $self->_disconnect;
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
  my ($self, $status) = @_;
  my $raw = $self->{raw};
  my $cooked = $self->{cooked};

  my ($vout, $iout, $on) = $self->_poll;
  $raw->{vout} = $vout;
  $raw->{iout} = $iout;

  if (defined $on) {
    $raw->{on} = $on;
    $cooked->{on} = $on;
  }

  if ($self->{'voltage-output'}) {
    $cooked->{vout} = $self->{'voltage-output'}->estimate($vout);
  } else {
    $cooked->{vout} = $vout;
  }
  if ($self->{'current-output'}) {
    $cooked->{iout} = $self->{'current-output'}->estimate($iout);
  } else {
    $cooked->{iout} = $iout;
  }

  $status->{voltage} = $cooked->{vout};
  $status->{current} = $cooked->{iout};
  $status->{power} = $cooked->{vout} * $cooked->{iout};
  if ($cooked->{iout} > 0) {
    $status->{resistance} = $cooked->{vout} / $cooked->{iout};
  }

  return $status;
}

=head2 getVoltageSetPoint

Get the voltage set point of the power supply.

=over

=item Return Value

in a scalar context, returns the calibrated voltage set point of the power supply.
This may be different from the actual value reported by the power supply if voltage calibration
data is available and will include calibration adjustments.

In a list context, returns a two element list containing the calibrated voltage set point followed
by the raw voltage set point.

=back

=cut

sub getVoltageSetPoint {
  my ($self) = @_;

  if (wantarray) {
    return ($self->{cooked}->{vset}, $self->{raw}->{vset});
  }

  return $self->{cooked}->{vset};
}

=head2 getCurrentSetPoint

Get the current set point of the power supply.

=over

=item Return Value

in a scalar context, returns the calibrated current set point of the power supply.
This may be different from the actual value reported by the power supply if current calibration
data is available and will include calibration adjustments.

In a list context, returns a two element list containing the calibrated current set point followed
by the raw current set point.

=back

=cut

sub getCurrentSetPoint {
  my ($self) = @_;

  if (wantarray) {
    return ($self->{cooked}->{iset}, $self->{raw}->{iset});
  }

  return $self->{cooked}->{iset};
}

=head2 getOutputVoltage

Get the output voltage of the power supply.

=over

=item Return Value

in a scalar context, returns the calibrated output voltage of the power supply.
This may be different from the actual value reported by the power supply if voltage calibration
data is available and will include calibration adjustments.

In a list context, returns a two element list containing the calibrated output voltage followed
by the raw output voltage.

=back

=cut

sub getOutputVoltage {
  my ($self) = @_;

  if (wantarray) {
    return ($self->{cooked}->{vout}, $self->{raw}->{vout});
  }

  return $self->{cooked}->{vout};
}

=head2 getOutputCurrent

Get the output current of the power supply.

=over

=item Return Value

in a scalar context, returns the calibrated output current of the power supply.
This may be different from the actual value reported by the power supply if current calibration
data is available and will include calibration adjustments.

In a list context, returns a two element list containing the calibrated output current followed
by the raw output current.

=back

=cut

sub getOutputCurrent {
  my ($self) = @_;

  if (wantarray) {
    return ($self->{cooked}->{iout}, $self->{raw}->{iout});
  }

  return $self->{cooked}->{iout};
}

=head2 setVoltage($voltage)

Set the power supply output voltage.

This method attempts to ensure constant voltage operation at the requested voltage. To do this, it
must also ensure that the output is on and that current limiting is unlikely by verifying that the
current set point is set to the maximum allowed value.

=over

=item $voltage

The voltage required from the power supply measured in volts.

=back

=cut

sub setVoltage {
  my ($self, $voltage) = @_;
  my $raw = $self->{raw};
  my $cooked = $self->{cooked};
  my ($min, $max) = $self->getVoltageLimits;

  my $vset;
  if (exists $self->{'voltage-requested'}) {
    $vset = $self->{'voltage-requested'}->estimate($voltage);
  } else {
    $vset = $voltage;
  }
  $vset = $min if $vset < $min;
  $vset = $max if $vset > $max;

  my ($ok, $on, $iset) = $self->_setVoltage($vset);

  croak "setVoltage: Failed to set output voltage" if !$ok;
  $raw->{vset} = $vset;
  $cooked->{vset} = $voltage;

  if (!defined $iset || $iset <= 0) {
    my ($min, $max) = $self->getCurrentLimits;
    $iset = $max;
    ($ok, $on) = $self->_setCurrent($iset);
    croak "setVoltage: Failed to set current set point" if !$ok;
  }
  $raw->{iset} = $iset;
  $cooked->{iset} = $self->{'current-setpoint'}->estimate($iset);

  if (!$on) {
    if (defined($on) || (!defined($on) && !$raw->{on})) {
  }

  return $self;
}

=head2 setCurrent($current)

Set the output current of the power supply as measured in amps.

This method attempts to ensure constant current operation at the specified current. To do this, it
must also ensure that the output is on and that voltage limiting is unlikely by verifying that the
voltage set point is set to the maximum allowed value.

=over

=item $current

The current required from the power supply measured in amps.

=back

=cut

sub setCurrent {
  my ($self, $current) = @_;
  my $raw = $self->{raw};
  my $cooked = $self->{cooked};
  my ($min, $max) = $self->getCurrentLimits;

  my $iset;
  if (exists $self->{'current-requested'}) {
    $iset = $self->{'current-requested'}->estimate($current);
  } else {
    $iset = $current;
  }
  $iset = $min if $iset < $min;
  $iset = $max if $iset > $max;

  my ($ok, $on, $vset) = $self->_setCurrent($iset);

  croak "setCurrent: Failed to set output current" if !$ok;
  $raw->{iset} = $iset;
  $cooked->{iset} = $current;

  if (!defined $vset || $vset <= 0) {
    my ($min, $max) = $self->getVoltageLimits;
    $vset = $max;
    ($ok, $on) = $self->_setVoltage($vset);
    croak "setCurrent: Failed to set voltage set point" if !$ok;
  }
  $raw->{vset} = $vset;
  $cooked->{vset} = $self->{'voltage-setpoint'}->estimate($vset);

  if (!$on) {
    if (defined($on) || (!defined($on) && !$raw->{on})) {
      $self->_on(1);
      $raw->{on} = 1;
      $cooked->{on} = 1;
    }
  }

  return $self;
}

=head2 setPower($power, $resistance)

Set the output power of the power supply.

This is done based on the assumed resistance of the load and then setting the voltage set point
to the square root of the power multiplied by the resistance. Voltage is used because:

1. Voltage regulation is often better than current regulation in many power supplies.
2. Normal materials tend to have a higher resistance at higher temperatures. This makes using
constant voltage more self-limiting in the event of some software fault.

=over

=item $power

The power required from the power supply measured in watts.

=item $resistance

An optional parameter providing the resistance of the load. If not provided, the resistance
will be calculated based on the most recent output voltage and current values. If the most
recent poll returned an output current of zero, then this method will croak. Commands should
make sure the output has been turned on and polled before doing anything that requires a
resistance measurement.

=back

=cut

sub setPower {
  my ($self, $power, $resistance) = @_;

  if (!defined $resistance) {
    my $iout = $self->getOutputCurrent;

    croak "setPower: Resistance measurement not available because iout = 0" if $iout <= 0;

    my $vout = $self->getOutputVoltage;

    croak "setPower: Resistance measurement not available because vout = 0" if $vout <= 0;

    $resistance = $vout / $iout;
  }

  my $voltage = sqrt($power * $resistance);
  my $vset;
  if (exists $self->{'voltage-requested'}) {
    $vset = $self->{'voltage-requested'}->estimate($voltage);
  } else {
    $vset = $voltage;
  }

  return $self->setVoltage($vset);
}

=head2 getMinimumCurrent

Get the minimum current required to measure the resistance of the hotplate. The default implementation returns 0.1 amps.

=over

=item Return Value

The minimum current required to measure the resistance of the hotplate.

=cut

sub getMinimumCurrent {
  my ($self) = @_;
  my ($min, $max) = $self->getCurrentLimits;
  return $min;
}

=head2 getMeasurableCurrent

Get the minimum current where resistance can reasonably be measured.

=cut

sub getMeasurableCurrent {
  my ($self) = @_;

  return $self->{current}->{measurable} || $self->getMinimumCurrent;
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

=head2 on($flag)

Turn the power supply output on or off.

It is important that this method sends only one request to the power supply. This class is used
inside an event loop where we need to keep event callbacks as quick as possible to avoid blocking
the event loop.

To be implemented by subclasses.

=over

=item $flag

If $flag is true, the power supply output is turned on.
If $flag is false, the power supply output is turned off.

=back

=cut

sub on {
  return;
}

=head2 resetCalibration

Reset the calibration of the power supply. This is mostly useful when recalibrating the
power supply. It removes all calibration data so that the requested and reported values
match the raw values sent to and returned by the power supply.

=cut

sub resetCalibration {
  my ($self) = @_;

  delete $self->{'voltage-requested'};
  delete $self->{'voltage-output'};
  delete $self->{'voltage-setpoint'};
  delete $self->{'current-requested'};
  delete $self->{'current-output'};
  delete $self->{'current-setpoint'};

  return;
}

=head1 PRIVATE METHODS

=head2 _connect

Connect to the power supply. This is used to initialize the interface and to get the
initial values from the power supply.

The connect method is generally not called from inside an event loop. It is most important
that it return the five values required in the return value. If that requires multiple requests,
so be it. Taking the time to retrieve them now regardless of whether it requires 1 request or
5 requests or somewhere in between may save us time later when we are inside the event loop.

=over

=item Return Value

Returns a five element list containing:

1. The raw voltage set point.
2. The raw current set point.
3. The on-state of the power supply output (true or false)
4. The raw voltage output.
5. The raw current output.

=back

=cut

sub _connect {
  return;
}

=head2 _disconnect

Disconnect from the power supply. This is used to close the connection to the power supply.

=cut

sub _disconnect {
  return;
}

=head2 _poll

Poll the power supply for the current status.

=over

=item Return Value

Returns a 3 element list containing the output voltage, output current and the on-state of the power
supply outputs.

It is assumed that the power supply will be able to retrieve this data in one request. If that is not
possible, we absolutely must retrieve voltage and current. If that cannot be done in a single request,
then make two separate requests for those. If also retrieving the on-state would require an additional
request, then return undef for the on-state and let the calling logic figure it out.

=back

=cut

sub _poll {
  return;
}

=head2 _setCurrent($current)

Set the output current set point of the power supply and if possible, ensure that the output is on and
the power supply will favour constant current operation. 

This method must blindly attempt to set the current output to the specified set point. Implementations
should assume that all necessary checks for minimums and maximums and all calibration adjustments have
already been performed.

This method must only make one request to the power supply. This class will be used inside an event loop
where we need to keep event callbacks as quick as possible to avoid blocking the event loop. We should
favour constant current operation (which generally requires setting the voltage set point to the maximum
allowed value) and ensure the output is on, but not if this requires sending multiple requests. If
multiple requests are required, that will be dealt with elsewhere.

=over

=item $current

The current to request from the power supply in amperes.

=item Return Value

Returns a three element list containing:

1. A true value if the current set point was successfully set.
2. A true value if the output was turned on or undef if this method cannot determine that.
3. The voltage set point that was actually set or undef if this method was unable to set the voltage set point.

Note that it is important to return these three values correctly as the calling logic will use them
and other data to determine whether multiple requests to the power supply may be required to achieve
the desired outcomes. (ie. current set, output on, constant current operation)

=back

=cut

sub _setCurrent {
  return;
}

=head2 _setVoltage($voltage)

Set the output voltage set point of the power supply and if possible, ensure that the output is on and
the power supply will favour constant voltage operation. 

This method must blindly attempt to set the voltage output to the specified set point. Implementations
should assume that all necessary checks for minimums and maximums and all calibration adjustments have
already been performed.

This method must only make one request to the power supply. This class will be used inside an event loop
where we need to keep event callbacks as quick as possible to avoid blocking the event loop. We should
favour constant voltage operation (which generally requires setting the current set point to the maximum
allowed value) and ensure the output is on, but not if this requires sending multiple requests. If
multiple requests are required, that will be dealt with elsewhere.

=over

=item $voltage

The voltage to request from the power supply in volts.

=item Return Value

Returns a three element list containing:

1. A true value if the voltage set point was successfully set.
2. A true value if the output was turned on or undef if this method cannot determine that.
3. The current set point that was actually set or undef if this method was unable to set the current set point.

Note that it is important to return these three values correctly as the calling logic will use them
and other data to determine whether multiple requests to the power supply may be required to achieve
the desired outcomes. (ie. voltage set, output on, constant voltage operation)

=back

=cut

sub _setVoltage {
  return;
}

=head2 _buildEstimator($input, $output, @key)

Build an estimator for the specified input and output values. The @key parameter is
a list of keys that are used to access the data in the configuration.

=cut

sub _buildEstimator {
  my ($self, $input, $output, @key) = @_;

  my $array = $self->{config}->exists(@key);

  my $estimator = PowerSupplyControl::Math::PiecewiseLinear->new;
  if ($array && @$array) {
    $estimator->addHashPoints($input, $output, @{$array});
  }
  
  # If we don't have at least two points, add the origin.
  if ($estimator->length < 2) {
    $estimator->addPoint(0,0);
  }

  # If we still don't have two points, make this an identity estimator.
  # Using negative values should avoid causing too many problems if real values are added later.
  if ($estimator->length < 2) {
    $estimator->addPoint(-1, -1);
  }

  return $estimator;
}

=head2 _buildCalibration

Build the calibration estimators for the power supply. This is used to convert the
raw values from the power supply into the requested and reported values.

=cut

sub _buildCalibration {
  my ($self) = @_;

  $self->{'voltage-requested'} = $self->_buildEstimator(qw(actual requested calibration voltage));
  $self->{'voltage-output'} = $self->_buildEstimator(qw(sampled actual calibration voltage));
  $self->{'voltage-setpoint'} = $self->_buildEstimator(qw(requested actual calibration voltage));
  $self->{'current-requested'} = $self->_buildEstimator(qw(actual requested calibration current));
  $self->{'current-output'} = $self->_buildEstimator(qw(sampled actual calibration current));
  $self->{'current-setpoint'} = $self->_buildEstimator(qw(requested actual calibration current));

  return;
}

1;
