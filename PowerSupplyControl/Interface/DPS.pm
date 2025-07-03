package PowerSupplyControl::Interface::DPS;

use strict;
use base qw(PowerSupplyControl::Interface Exporter);
use IO::Dir;
use Readonly;
use List::Util qw(min max);
use PowerSupplyControl::Math::PiecewiseLinear;

use Device::Modbus::RTU::Client;
use Math::Round;

use Exporter 'import';

Readonly my %DPS_MODELS => ( 5020 => { name => 'DPS5020'
                                     , Vmax => 50
                                     , Imax => 20.1
                                     }
                           , 5205 => { name => 'DPH5005'
                                     , Vmax => 50
                                     , Imax => 5.1
                                     }
                           , 5005 => { name => 'DPS5005'
                                     , Vmax => 50
                                     , Imax => 5.1
                                     }
                           , 5015 => { name => 'DPS5015'
                                     , Vmax => 50
                                     , Imax => 15.1
                                     }
                           , 3005 => { name => 'DPS3005'
                                     , Vmax => 30
                                     , Imax => 5.1
                                     }
                           , 3003 => { name => 'DPS3003'
                                     , Vmax => 30
                                     , Imax => 3.1
                                     }
                           , 8005 => { name => 'DPS8005'
                                     , Vmax => 80
                                     , Imax => 5.1
                                     }
                           );

=head1 SYNOPSIS

  my $interface = PowerSupplyControl::Interface::DPS->new(baudrate => 19200
                                        , address  => 1
                                        , current  => { maximum => 12
                                                      , minimum => 0.1
                                                      }
                                        , voltage  => { maximum => 30
                                                      , minimum => 1
                                                      }
                                        );

  my $status = $interface->poll;

  ...
  
  my $power = $controller->power($currentTemp, $futureTemp, $now, $then);

  $interface->setPower($power);

=head1 DESCRIPTION

Interface definition for an interface with a power supply.

=cut

our @EXPORT = qw($REG_V_SET
                 $REG_I_SET
                 $REG_V_OUT
                 $REG_I_OUT
                 $REG_POWER
                 $REG_V_IN
                 $REG_LOCK
                 $REG_PROTECT
                 $REG_CVCC
                 $REG_OUT_EN
                 $REG_B_LED
                 $REG_MODEL
                 $REG_VERSION
                 );

Readonly my $BASE_TEMP => 20;

=head2 CONSTANTS

The following constants may be imported on demand into other modules as may be required.

=over

=item $REG_V_SET

The register address for the current set voltage of the power supply.

=item $REG_I_SET

The register address for the current set current of the power supply.

=item $REG_V_OUT

The register address for the current output voltage of the power supply.

=item $REG_I_OUT

The register address for the current output current from the power supply.

=item $REG_POWER

The register address for the current output power from the power supply. This should generally return the same value as the output voltage multiplied by the output current but may be slightly different due to rounding.

=item $REG_V_IN

the register address for the current input voltage for the power supply.

=item $REG_LOCK

The register address for the current lock setting of the power supply.

=item $REG_PROTECT

The register address for the protect flag on the power supply.

=item $REG_CVCC

The register address for the constant current/constant voltage flag of the power supply.

=item $REG_OUT_EN

The register address for the output enable flag of the power supply.

=item $REG_B_LED

Who knows what this register is for? Turning the OLED screen on/off, maybe?

=item $REG_MODEL

The register address for returning the model identifier for the power supply.

=item $REG_VERSION

The register address for returning the firmware version of the power supply.

=cut

Readonly our $REG_V_SET   => 0;
Readonly our $REG_I_SET   => 1;
Readonly our $REG_V_OUT   => 2;
Readonly our $REG_I_OUT   => 3;
Readonly our $REG_POWER   => 4;
Readonly our $REG_V_IN    => 5;
Readonly our $REG_LOCK    => 6;
Readonly our $REG_PROTECT => 7;
Readonly our $REG_CVCC    => 8;
Readonly our $REG_OUT_EN  => 9;
Readonly our $REG_B_LED   => 10;
Readonly our $REG_MODEL   => 11;
Readonly our $REG_VERSION => 12;

Readonly my @FACTOR => ( 100    # V-set
                       , 1000   # I-set
                       , 100    # V-out
                       , 1000   # I-out
                       , 100    # Power
                       , 100    # V-in
                       );

=head1 CONSTRUCTOR

=head2 new(<named arguments>)

Create a new DPS interface object with the specified properties.

=cut

sub new {
  my ($class, $config) = @_;

  # Include default values ahead of argument array so that arguments will override defaults
  my $self = $class->SUPER::new($config);
  $self->{factor} = [ @FACTOR ];

  bless $self, $class;

  if (!$self->{port}) {
    my @devs = $self->findUSBDevs;
    if (! $self->openDPSPort(@devs)) {
      die "Unable to open connection to DPS power supply!\n";
    }
  }

  $self->fetch;

  # If no specific ifactor was specified and the maximum current is higher than 10 amps, assume only 2 decimal places for current
  if (substr($self->model, 2, 2) > 10) {
    $self->{factor}->[1] = 100;
    $self->{factor}->[3] = 100;
    $self->fetch;
  }
  
  if ($self->{calibration}) {
    $self->_setupCalibration('current', $self->{calibration}->{current});
    $self->_setupCalibration('voltage', $self->{calibration}->{voltage});
  }

  return $self;
}

sub _setupCalibration {
  my ($self, $name, $points) = @_;

  return unless $points && @$points;

  my $outputCal = PowerSupplyControl::Math::PiecewiseLinear->new;
my $requestedCal = PowerSupplyControl::Math::PiecewiseLinear->new;
  foreach my $point (@$points) {
    if (exists $point->{actual}) {
      if (exists $point->{sampled}) { 
        $outputCal->addPoint($point->{sampled}, $point->{actual});
      }

      if (exists $point->{requested}) {
        $requestedCal->addPoint($point->{actual}, $point->{requested});
      }
    }
  };

  if ($outputCal->length >= 2) {
    $self->{calibration}->{output}->{$name} = $outputCal;
  }

  if ($requestedCal->length >= 2) {
    $self->{calibration}->{requested}->{$name} = $requestedCal;
  }
}

=head2 openDPSPort(@devs)

Open a connection to a DPS power supply.

=over

=item @devs

The list of device names to try to open a connection to.

=back

=cut

sub openDPSPort {
  my ($self, @devs) = @_;

  foreach my $dev (@devs) {
    my $client = Device::Modbus::RTU::Client->new(
          port => $dev
        , baudrate => $self->{baudrate}
        , parity => $self->{parity}
        , values => []
        );

    # If we have a client, try to retrieve the model number and firmware revision
    if ($client) {
      my $req = $client->read_holding_registers(address => 0, unit => $self->{address}, quantity => $REG_VERSION + 1);
      $client->send_request($req);
      my $resp = undef;
      eval {
        $resp = $client->receive_response;
      };

      if ($resp && $resp->success) {
        my $model = $resp->values->[$REG_MODEL];
        my $version = $resp->values->[$REG_VERSION];

        if (exists $DPS_MODELS{$model}) {
          $self->{client} = $client;
          $self->{port} = $dev;

          $self->{Vmax} = min($DPS_MODELS{$model}->{Vmax}, $self->{Vmax}, $resp->values->[$REG_V_IN] - 2);
          $self->{Imax} = min($DPS_MODELS{$model}->{Imax}, $self->{Imax});
          $self->{model} = $DPS_MODELS{$model}->{name};

          return $client;
        }
      }
    }
  }

  return;
}

sub findUSBDevs {
  my ($self) = @_;
  my @devs;

  my $dh = IO::Dir->new('/dev') || die "opendir: /dev: $!";

  while (my $name = $dh->read) {
    if ($name =~ /^ttyUSB\d+$/) {
      push @devs, "/dev/$name";
    }
  }

  $dh->close;

  return @devs;
}

=head2 poll

Poll the power supply and/or heating element for current status. The return value is a reference to a hash containing current status information. Subclasses may provide additional values, but they must provide the following as a bare minimum:

=over

=item voltage

The current voltage across the heating element. This value includes any calibration corrections that may be available.

=item current

The current current through the heating element. This value includes any calibration corrections that may be available.

=item power

The current power being delivered to the heating element. This value is the product of the voltage and current values also being returned.

=item resistance

The current resistance of the heating element. This should normally be equal to voltage divided by current. If current is zero, this value will not be returned.

=back

=cut

sub poll {
  my ($self, $status) = @_;

  # Fetch the output voltage and current
  $self->fetch($REG_V_OUT, 2);
  my $current = $self->iout;
  my $voltage = $self->vout;

  if (exists $self->{calibration}->{output}) {
    my $outputCal = $self->{calibration}->{output};

    if (exists $outputCal->{current}) {
      $status->{'raw-current'} = $current;
      $current = $outputCal->{current}->estimate($current);
    }

    if (exists $outputCal->{voltage}) {
      $status->{'raw-voltage'} = $voltage;
      $voltage = $outputCal->{voltage}->estimate($voltage);
    }
  }

  $status->{voltage} = $voltage;
  $status->{current} = $current;
  $status->{power} = $voltage * $current;
  if($current > 0) {
    $status->{resistance} = $voltage / $current;
  }

  return $status;
}

=head2 setPower($pwr, $r)

Set the current heating element power level. This is presumably done by adjusting the output voltage and/or current of the power supply. Where possible, subclasses should attempt to set the power supply output such that the power supplied to the element itself matches the commanded power level. Where not possible this may instead set the output power of the power supply.

=over

=item $pwr

The power level to be commanded to the heating element.

=item $r

The assumed resistance of the heating element. If not provided or otherwise invalid, the resistance will be calculated using the last retrieved output voltage and current.

=back

=cut

sub setPower {
  my ($self, $pwr, $r) = @_;

  # If power is not positive, then turn off the output
  if ($pwr <= 0) {
    return $self->on(0);
  }

  if ($pwr > $self->{power}->{maximum}) {
    $pwr = $self->{power}->{maximum};
  }

  # Need the current heating element resistance if not provided
  if ($r <= 0) {

    # if the output current is zero, then turn on the output and set minimum current
    if (! $self->iout) {
      $self->setCurrent($self->{current}->{minimum} || 1);

      # Re-poll to get the output voltage and current
      $self->poll;
    }

    $r = $self->vout / $self->iout;
  }

  my $vset = min(max(sqrt($pwr * $r), $self->{voltage}->{minimum}), $self->{voltage}->{maximum});
  my $iexpected = $vset / $r;
  if ($iexpected < $self->{current}->{minimum}) {
    return $self->setCurrent($self->{current}->{minimum});
  }

  return $self->setVoltage($vset);
}

=head2 setCurrent($amps)

Set the output current of the power supply directly.

The current values will be limited to the minimum and maximum current limits defined for this interface.

If calibration data is available, the requested current will be adjusted with calibration corrections.

=over

=item $amps

The output current setting in amperes. This will be limited to the minimum and maximum current limits defined for this interface.

=item $volts

The output voltage setting in volts. In order to create the best chance of the power supply operating in constant current mode,
this will default to the maximum output voltage defined for this interface. If a value is provided, it will be limited to the
maximum output voltage defined for this interface and sent to the power supply.

=back

=cut

sub setCurrent {
  my ($self, $amps, $volts) = @_;

  if ($self->{current}->{minimum} > 0 && $amps < $self->{current}->{minimum}) {
    $amps = $self->{current}->{minimum};
  }

  if ($amps > $self->{current}->{maximum}) {
    $amps = $self->{current}->{maximum};
  }

  if (exists $self->{calibration}->{requested}->{current}) {
    $amps = $self->{calibration}->{requested}->{current}->estimate($amps);
  }

  if (!defined($volts) || $volts > $self->{voltage}->{maximum}) {
    $volts = $self->{voltage}->{maximum};
  } elsif ($self->{voltage}->{minimum} > 0 && $volts < $self->{voltage}->{minimum}) {
    $volts = $self->{voltage}->{minimum};
  }

  $self->set(voltage => $volts, current => $amps, enable => 1);
}

=head2 setVoltage($volts [, $amps])

Set the output voltage of the power supply directly.

The voltage values will be limited to the minimum and maximum voltage limits defined for this interface.

If calibration data is available, the requested voltage will be adjusted with calibration corrections.

=over

=item $volts

The output voltage limit specified in volts.

=item $amps

The output current limit specified in amps. In order to create the best chance of the power supply operating in constant voltage mode,
this will default to the maximum output current allowed for this interface. If a value is provided, it will be limited to the
maximum output current allowed for this interface and sent to the power supply.

=back

=cut

sub setVoltage {
  my ($self, $volts, $amps) = @_;

  # If voltage is set to zero, turn off the output
  if ($volts <=0) {
    return $self->on(0);
  }

  if ($self->{voltage}->{minimum} > 0 && $volts < $self->{voltage}->{minimum}) {
    $volts = $self->{voltage}->{minimum};
  }

  if ($volts > $self->{voltage}->{maximum}) {
    $volts = $self->{voltage}->{maximum};
  }

  if (exists $self->{calibration}->{requested}->{voltage}) {
    $volts = $self->{calibration}->{requested}->{voltage}->estimate($volts);
  }

  if (!defined($amps) || $amps > $self->{current}->{maximum}) {
    $amps = $self->{current}->{maximum};
  } elsif ($self->{current}->{minimum} > 0 && $amps < $self->{current}->{minimum}) {
    $amps = $self->{current}->{minimum};
  }

  $self->set(voltage => $volts, current => $amps, enable => 1);
}


# Utility method to convert fractional values supplied via method calls into the integer values expected when setting registers on the power supply via ModBus protocol.
sub intify {
  my ($self, $addr, $val) = @_;

  if ($addr < @FACTOR) {
    return int($val * $self->{factor}->[$addr]);
  }

  return $val;
}

=head2 setMinCurrent($minCurrent)

Set the minimum current limit for the power supply.

=over

=item $minCurrent

The new value to use for the minimum output current of the power supply.

If not defined and the minimum current has previously been changed using this method, restores the default value.

=back

=cut

sub setMinCurrent {
  my ($self, $minCurrent) = @_;

  if (exists($self->{current}->{minimum}) && !exists($self->{current}->{'__minimum'}) && defined $minCurrent) {
    $self->{current}->{'__minimum'} = $self->{current}->{minimum};
  }

  if (!defined $minCurrent && exists($self->{current}->{'__minimum'})) {
    $self->{current}->{minimum} = $self->{current}->{'__minimum'};
  } else {
    $self->{current}->{minimum} = $minCurrent;
  }

  return;
}

=head2 getMinimumCurrent

Get the minimum current required to measure the resistance of the hotplate.

=cut

sub getMinimumCurrent {
  my ($self) = @_;

  return $self->{current}->{minimum} || 0.1;
}

# Utility method to convert integer values retrieved from registers via ModBus protocol into fractional values in correct units such as volts, amps and watts.
sub deintify {
  my ($self, $addr, $val) = @_;

  if ($addr < @FACTOR) {
    return $val / $self->{factor}->[$addr];
  }

  return $val;
}

=head2 shutdown

Turn the power supply output off, close the connection to the power supply and release all resources. 

=cut

sub shutdown {
  my $self = shift;
  if ($self->{client}) {
    $self->on(0);
    $self->{client}->disconnect;
    delete $self->{client};
  }
}

=head2 fetch($address, $count)

Retrieve the value of a number of registers beginning at a given address.

=over

=item $address

The starting address register values to be retrieved.

=item $count

The number of register values to be retrieved.

=back

=cut

sub fetch {
  my $self = shift;
  my $address = shift || 0;
  my $count = shift || 13;

  if ($count+$address > 13) {
    $count = 13 - $address;
  }

  my $req = $self->{client}->read_holding_registers(address => $address, unit => $self->{address}, quantity => $count);
  $self->{client}->send_request($req);
  my $resp = $self->{client}->receive_response;

  if ($resp->success) {
    for(my $i=0; $i<$count; $i++, $address++) {
      $self->{values}->[$address] = $self->deintify($address, $resp->values->[$i]);
    }
  }

  return;
}

Readonly my %INDEX => ( voltage => $REG_V_SET
                      , current => $REG_I_SET
                      , lock    => $REG_LOCK
                      , enable  => $REG_OUT_EN
                      , b_led   => $REG_B_LED
                      );
Readonly my %WRITABLE => reverse %INDEX;

# Utility method to help build request objects for writing registers.
sub buildWriteRequest {
  my $self = shift;
  my $addr = 100000;
  my $values = [];
  
  while (@_) {
    my $key = shift;
    my $val = shift;

    if (defined (my $index = $INDEX{$key})) {
      $values->[$index] = $self->intify($index, $val);
      if ($index < $addr) {
        $addr = $index;
      }
    }
  }

  for(my $i=0; $i<@$values; $i++) {
    if (! exists($values->[$i])) {
      if (exists($WRITABLE{$i})) {
        $values->[$i] = $self->intify($i, $self->{values}->[$i]);
      } else {
        $values->[$i] = 0;
      }
    }
  }

  return ($addr, @$values[$addr..$#$values]) if @$values;
  return;
}

=head2 set1($addr, $val)

Set the value of a single register on the power supply.

=over

=item $addr

The address of the register to be set.

=item $val

The value to be specified for the register. Values should be specified in real-world units such as volts or amps where applicable. The module will perform any appropriate conversions required to communicate the correct value to the power supply.

=back

=cut

sub set1 {
  my ($self, $addr, $val) = @_;

  my $req = $self->{client}->write_single_register(address => $addr, unit => $self->{address}, value => $self->intify($addr, $val));
  $self->{client}->send_request($req);
  return $self->{client}->receive_response;
}

=head2 set($addr, @values)

Set the value of multiple registers in a single request. The registers to be set must form a contiguous set of addresses. The number of registers to be set will be set by the number of values provided.

=over

=item $addr

The starting address of the registers to be set.

=item @values

A list of values to be set for the registers starting at address $addr.

=back

=cut

sub set {
  my $self = shift;
  my ($addr, @values) = $self->buildWriteRequest(@_);

  my $req = $self->{client}->write_multiple_registers(address => $addr, unit => $self->{address}, values => \@values);
  $self->{client}->send_request($req);
  return $self->{client}->receive_response;
}

=head2 vset([ $volts ])

Get or set the output voltage limit on the power supply. If no argument is provided, this method merely returns the output voltage limit that was retrieved in the last poll. If a value is provided, sends that value to the power supply as the new output voltage limit.

=cut

sub vset {
  my $self = shift;

  if (@_) {
    $self->set1($REG_V_SET, shift);
    return;
  }

  return $self->{values}->[$REG_V_SET];
}

=head2 iset([ $amperes ])

Get or set the output current limit on the power supply. If no argument is provided, this method merely returns the output current limit that was retrieved in the last poll. If a value is provided, sends that value to the power supply as the new output current limit.

=cut

sub iset {
  my $self = shift;

  if (@_) {
    $self->set1($REG_I_SET, shift);
    return;
  }

  return $self->{values}->[$REG_I_SET];
}

=head2 vout

Return the output voltage returned in the last poll.

=cut

sub vout {
  return $_[0]->{values}->[$REG_V_OUT];
}

=head2 iout

Return the output current returned in the last poll.

=cut

sub iout {
  return $_[0]->{values}->[$REG_I_OUT];
}

=head2 power

Return the output power retrieved in the last poll.

=cut

sub power {
  return $_[0]->{values}->[$REG_POWER];
}

=head2 vin

Return the power supply input voltage returned in the last poll.

=cut

sub vin {
  return $_[0]->{values}->[$REG_V_IN];
}

sub lock {
  my $self = shift;

  if (@_) {
    $self->set1($REG_LOCK, shift);
    return;
  }

  return $self->{values}->[$REG_LOCK];
}

sub protect {
  return $_[0]->{values}->[$REG_PROTECT];
}

sub cvcc {
  return $_[0]->{values}->[$REG_CVCC];
}

=head2 on([ $boolean ])

If no argument is provided, then returns the on state of the power supply, with a true value indicating that the output is enabled and a false value indicating that the output is disabled.

If an argument is provided, then sets the output enable state of the power supply. A true value enables the output. A false value disables the output.

=cut

sub on {
  my $self = shift;

  if (@_) {
    $self->set1($REG_OUT_EN, shift);
    return;
  }

  return $self->{values}->[$REG_OUT_EN];
}

=head2 off([ $boolean ])

If no argument is provided, then returns the on state of the power supply, with a true value indicating that the output is disabled and a false value indicating that the output is enabled.

If an argument is provided, then sets the output enable state of the power supply. A true value disables the output. A false value enables the output.

Note that both the return value and the $boolean flag are interpreted in the opposite way to the on() method.

=cut

sub off {
  my $self = shift;

  if (@_) {
    return $self->on(! shift);
  }

  return !$self->on;
}

sub b_led {
  my $self = shift;

  if (@_) {
    $self->set1($REG_B_LED, shift);
    return;
  }

  return $self->{values}->[$REG_B_LED];
}

=head2 model

Return the power supply model for the connected power supply.

=cut

sub model {
  return $_[0]->{values}->[$REG_MODEL];
}

=head2 version

Return the firmware version of the connected power supply.

=cut

sub version {
  return $_[0]->{values}->[$REG_VERSION];
}

sub getMaximumPower {
  my $self = shift;

  return $self->{power}->{maximum} || 120;
}

1;
