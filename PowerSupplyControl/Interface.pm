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
  my $self = $config;

  bless $self, $class;

  $self->_buildCalibration;

  my ($vset, $iset, $on, $vout, $iout);
  
  if  (($vset, $iset, $on, $vout, $iout) = $self->_connect) {
    $self->{connected} = 1;
  } else {
    croak ref($self) .': Unable to connect to power supply';
  }

  # Store the raw values as reported by the power supply.
  $self->{raw} = { vset => $vset
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

  $self->{cooked} = $cooked;

  if (!exists $self->{current}) {
    $self->{current} = {};
  }
  if (!exists $self->{voltage}) {
    $self->{voltage} = {};
  }
  if (!exists $self->{power}) {
    $self->{power} = {};
  }

  return $self;
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
  $status->{'raw-voltage'} = $raw->{vout};
  $status->{'raw-current'} = $raw->{iout};
  $status->{'raw-power'} = $raw->{vout} * $raw->{iout};
  if ($cooked->{iout} > 0) {
    $status->{resistance} = $cooked->{vout} / $cooked->{iout};
    $status->{'raw-resistance'} = $raw->{vout} / $raw->{iout};
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

=head2 isOn

Check if the power supply is on.

=over

=item Return Value

Returns true if the power supply is on, false otherwise.

=back

=cut

sub isOn {
  my ($self) = @_;
  return $self->{raw}->{on};
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
  my ($vmin, $vmax) = $self->getVoltageLimits;
  my ($imin, $imax) = $self->getCurrentLimits;
  my ($pmin, $pmax) = $self->getPowerLimits;

  my $vset;
  if (exists $self->{'voltage-requested'}) {
    $vset = $self->{'voltage-requested'}->estimate($voltage);
  } else {
    $vset = $voltage;
  }
  $vset = $vmin if $vset < $vmin;
  $vset = $vmax if $vset > $vmax;

  my $irec = $imax;
  if (($vset*$irec) > $pmax) {
    $irec = $pmax / $vset;
  }

  my ($ok, $on, $iset) = $self->_setVoltage($vset, $irec);

  croak "setVoltage: Failed to set output voltage" if !$ok;
  $raw->{vset} = $vset;

  if ($self->{'voltage-setpoint'}) {
    $cooked->{vset} = $self->{'voltage-setpoint'}->estimate($vset);
  } else {
    $cooked->{vset} = $vset;
  }

  if (!defined $iset || $iset <= 0) {
    ($ok, $on) = $self->_setCurrent($irec);
    croak "setVoltage: Failed to set current set point" if !$ok;
    $iset = $irec;
  }
  $raw->{iset} = $iset;
  if ($self->{'current-setpoint'}) {
    $cooked->{iset} = $self->{'current-setpoint'}->estimate($iset);
  } else {
    $cooked->{iset} = $iset;
  }

  if ($on) {
    $raw->{on} = $cooked->{on} = 1;
  } else {
    if (defined($on) || (!defined($on) && !$raw->{on})) {
      $self->_on(1);
      $raw->{on} = 1;
      $cooked->{on} = 1;
    }
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
  my ($vmin, $vmax) = $self->getVoltageLimits;
  my ($imin, $imax) = $self->getCurrentLimits;
  my ($pmin, $pmax) = $self->getPowerLimits;

  my $iset;
  if (exists $self->{'current-requested'}) {
    $iset = $self->{'current-requested'}->estimate($current);
  } else {
    $iset = $current;
  }
  $iset = $imin if $iset < $imin;
  $iset = $imax if $iset > $imax;

  my $vrec = $vmax;
  if (($iset*$vrec) > $pmax) {
    $vrec = $pmax / $iset;
  }

  my ($ok, $on, $vset) = $self->_setCurrent($iset, $vrec);

  croak "setCurrent: Failed to set output current" if !$ok;
  $raw->{iset} = $iset;

  if ($self->{'current-setpoint'}) {
    $cooked->{iset} = $self->{'current-setpoint'}->estimate($iset);
  } else {
    $cooked->{iset} = $iset;
  }

  if (!defined $vset || $vset <= 0) {
    ($ok, $on) = $self->_setVoltage($vrec);
    croak "setCurrent: Failed to set voltage set point" if !$ok;
    $vset = $vrec;
  }

  $raw->{vset} = $vset;
  if ($self->{'voltage-setpoint'}) {
    $cooked->{vset} = $self->{'voltage-setpoint'}->estimate($vset);
  } else {
    $cooked->{vset} = $vset;
  }

  if ($on) {
    $raw->{on} = $cooked->{on} = 1;
  } else {
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
  my ($pmin, $pmax) = $self->getPowerLimits;

  $power = $pmin if $power < $pmin;
  $power = $pmax if $power > $pmax;

  if (!defined $resistance) {
    my $iout = $self->getOutputCurrent;

    # We *could* call setCurrent to set the output to a measureable current level and turn
    # the output on, wait a bit for the output to settle and then poll to get a resistance
    # measurement, but we're probably inside an event loop. This could generate multiple
    # extra request-response cycles plus that settling time, which could block the event loop
    # for much longer than the sampling period. Better to croak and require commands that
    # need to use setPower to ensure the power supply is turned on and polled before the
    # event loop start - probably in the preprocess method.
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

Since these are often set to values to avoid triggering hardware protections like overcurrent
protection that may shut down the power supply, these values are interpreted as raw values - as in
the values actual sent to the power supply after calibration adjustments are applied.

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

Since these are often set to values to avoid triggering hardware protections like overvoltage
protection that may shut down the power supply, these values are interpreted as raw values - as in
the values actual sent to the power supply after calibration adjustments are applied.

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

Since these are often set to values to avoid triggering hardware protections like overpower
protection that may shut down the power supply, these values are interpreted as raw values - as in
the values actual sent to the power supply after calibration adjustments are applied.

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

=item Return Value

Returns true if the output state was set to the desired value or false otherwise.

=back

=cut

sub on {
  my ($self, $flag) = @_;

  $flag = $flag ? 1 : 0;

  if ($self->_on($flag)) {
    $self->{raw}->{on} = $self->{cooked}->{on} = $flag;
    return 1;
  }
  
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
  croak ref($_[0]) .': _connect not implemented.';
}

=head2 _disconnect

Disconnect from the power supply. This is used to close the connection to the power supply.

=cut

sub _disconnect {
  croak ref($_[0]) .': _disconnect not implemented.'
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
  croak ref($_[0]) .': _poll not implemented.'
}

=head2 _on($flag)

Set the on-state of the power supply without affecting anything else.

This method should blindly set the on-state of the power supply and should aim to do so in a single
request if possible, or in as few requests as possible.

=over

=item $flag

A true value indicates that the output should be turned on/enabled.
A false value indicates that the output should be turned off/disabled.

=item Return Value

Returns true if the output was set to the desired on-state or false otherwise.

=back

=cut

sub _on {
  croak ref($_[0]) .': not implemented.'
}

=head2 _setCurrent($current, $recommendedVoltage)

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

=item $recommendedVoltage

The recommended voltage to set to favour constant current operation while staying within current and power limits.
If the subclass can set voltage and current in one request, it is generally a good idea to blindly set the
voltage set point to this value.

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
  croak ref($_[0]) .': _setCurrent not implemented.';
}

=head2 _setVoltage($voltage, $recommendedCurrent)

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

=item $recommendedCurrent

The recommended current to set to favour constant voltage operation while staying within current and power limits.
If the subclass can set voltage and current in one request, it is generally a good idea to blindly set the
current set point to this value.

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
  croak ref($_[0]) .': _setVoltage not implemented.';
}

=head2 _buildEstimator($input, $output, @key)

Build an estimator for the specified input and output values. The @key parameter is
a list of keys that are used to access the data in the configuration.

=cut

sub _buildEstimator {
  my ($self, $input, $output, @key) = @_;

  my $fullKey = join('.', @key);
  my $array = $self;
  while ($array && @key) {
    my $key = shift @key;

    if (exists $array->{$key}) {
      $array = $array->{$key};
    } else {
      $array = undef;
      last;
    }
  }

  my $estimator = PowerSupplyControl::Math::PiecewiseLinear->new;
  if ($array && @$array) {
    $estimator->addHashPoints($input, $output, @{$array});
  }
  
  # No data, no estimator.
  return if ($estimator->length == 0);

  # If we don't have at least two points, add the origin.
  if ($estimator->length < 2) {
    $estimator->addPoint(0,0);
  }

  return $estimator;
}

=head2 _buildCalibration

Build the calibration estimators for the power supply. This is used to convert the
raw values from the power supply into the requested and reported values.

=cut

sub _buildCalibration {
  my ($self) = @_;

  my $est = $self->_buildEstimator(qw(actual requested calibration voltage));
  if ($est) {
    $self->{'voltage-requested'} = $est;
  }
  $est = $self->_buildEstimator(qw(sampled actual calibration voltage));
  if ($est) {
    $self->{'voltage-output'} = $est;
  }
  $est = $self->_buildEstimator(qw(requested actual calibration voltage));
  if ($est) {
    $self->{'voltage-setpoint'} = $est;
  }
  $est = $self->_buildEstimator(qw(actual requested calibration current));
  if ($est) {
    $self->{'current-requested'} = $est;
  }
  $est = $self->_buildEstimator(qw(sampled actual calibration current));
  if ($est) {
    $self->{'current-output'} = $est;
  }
  $est = $self->_buildEstimator(qw(requested actual calibration current));
  if ($est) {
    $self->{'current-setpoint'} = $est;
  }

  return;
}

1;
