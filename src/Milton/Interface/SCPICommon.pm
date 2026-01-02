package Milton::Interface::SCPICommon;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Interface);
use Carp qw(croak);
use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant CONNECTION_DEBUG => 10;
use constant REQUEST_DEBUG => 50;
use constant RESPONSE_DEBUG => 100;

=head1 NAME

Milton::Interface::SCPICommon - Common implementation for SCPI-based power supplies.

=head1 SYNOPSIS

=head1 DESCRIPTION

Common implementation for SCPI-based power supplies. Implements the basic command structure for what is
needed, but does not implement the transport mechanism to send commands and receive responses. That is
implemented in subclasses such as Milton::Interface::SCPI::Serial and Milton::Interface::SCPI::USBTMC.

This class allows customization of the SCPI command strings used in the event that a given power supply
requires slightly different command syntax than standard SCPI commands. The following default commands
are usually used by this class, unless overridden in the configuration.
these commands:

=over

=item *IDN?

The identification query command. Retrieves device information such as model number, serial number and firmware version.

=item MEAS:ALL?

Queries the power supply for voltage, current and power values. Expects a response with 3 numbers - voltage, current and power, in that order.

=item VOLT?

Queries the power supply for the voltage set point.

=item CURR?

Queries the power supply for the current set point.

=item VOLT <voltage>

Sets the voltage set point.

=item CURR <current>

Sets the current set point.

=item OUTP

Sets the output on or off.

=item OUTP?

Queries the power supply for the state of the output (ie. on or off).

=back

=head1 CONSTRUCTOR

=head2 new($config)

Create a new SCPI interface object. This constructor should not be called directly as this class does not
implement the necessary code to connect to a power supply. You should construct one of teh subclasses of this
class instead, such as Milton::Interface::SCPI::Serial or Milton::Interface::SCPI::USBTMC.

=over

=item $config

A reference to a hash of named configuration parameters. The following parameters are supported by this class,
in addition to those supported by the Milton::Interface class, from  which it is descended.

=over

=item id-pattern

A regular expression pattern to use to match with the appropriate power supply when connecting. If the id
details returned by the power supply from the *IDN? command, 

=item init-commands

An array of SCPI command strings to send to the power supply upon connecting. This is useful for sending any
commands required to setup the state of the remote control interface, such as selecting a default output
channel. If not specified, no custom initialization commands are sent.

=item shutdown-commands

An array of SCPI command strings to send to the power supply upon disconnecting. This is useful for sending any
custom commands that may be required to restore normal operation after the script exits. Note that the
disconnect method will automatically turn off the output using the OUTP OFF command or equivalent. Things that
you may want to consider including in this list are things like an *UNLOCK command to unlock the user interface.

=item command-length

The maximum length of a single SCPI command string that can be sent to the power supply. This does not include
the trailing newline character. If not specified, this detaults to a large value that effectively disables
command length checking. This is useful for power supplies that have limited command buffer space and may
not accept command string that are too long when chaining multiple commands together.

=item voltage-format

A format string to use when formatting voltage values for the set voltage command. This must be a printf
compatible format string without the leading % character. If not specified, the default format of .2f is
used. 

=item current-format

A format string to use when formatting current values for the set current command. This must be a printf
compatible format string without the leading % character. If not specified, the default format of .3f is
used. 

=item voltage-setpoint-command

The SCPI command string to use for setting the output voltage set point. If not specified, the default value
of VOLT? is used. 

=item current-setpoint-command

The SCPI command string to use for setting the output current set point. If not specified, the default value
of CURR? is used.

=item get-identity-command

The SCPI command string to use for getting the identity of the power supply. If not specified, the default value
of *IDN? is used.

=item set-voltage-command

The SCPI command string to use for setting the output voltage set point. If not specified, the default value
of VOLT is used.

=item set-current-command

The SCPI command string to use for setting the output current set point. If not specified, the default value
of CURR is used.

=item get-output-command

The SCPI command string to use for getting the output state of the power supply. If not specified, the default value
of MEAS:ALL? is used.

=item on-off-command

The SCPI command string to use for setting the output state of the power supply. If not specified, the default value
of OUTP is used.

=back

=cut

sub new {
  my ($class, $config) = @_;

  if (DEBUG_LEVEL >= 1) {
    if ($config->{logger}) {
      my $logger = $config->{logger};
      foreach my $key (sort keys %$config) {
        $logger->debug('Config %s: %s', $key, $config->{$key}) if !ref($config->{$key});
      }
    }
  }

  if ($config->{'id-pattern'}) {
    $config->{'id-pattern-re'} = qr/$config->{'id-pattern'}/;
  }

  my $self = $class->SUPER::new($config);

  $self->{'voltage-setpoint-command'} //= 'VOLT?';
  $self->{'current-setpoint-command'} //= 'CURR?';
  $self->{'get-identity-command'} //= '*IDN?';
  $self->{'set-voltage-command'} //= 'VOLT';
  $self->{'set-current-command'} //= 'CURR';
  $self->{'get-output-command'} //= 'MEAS:ALL?';
  $self->{'on-off-command'} //= 'OUTP';

  $self->{'command-length'} //= 10000;

  if (DEBUG_LEVEL >= 10) {
    foreach my $key (sort keys %$self) {
      $self->debug('Object %s: %s', $key, $self->{$key}) if !ref($self->{$key});
    }
  }

  return $self;
}

=head2 _connect

Initialize the interface object and it's connection to the power supply. This includes the following steps:

=over

Initialize the connection to the power supply by creating a suitable helper object.

Verifying the identity of the power supply (ie. make, model, id-pattern, etc).

Send any required initialization commands to the power supply.

=back

This method should not be overridden by subclasses. For most purposes, any subclass specific setup can be
achieved in the initializeConnection method.

=cut

sub _connect {
  my ($self) = @_;

  $self->{helper} = $self->initializeConnection; 

  if ($self->{'init-commands'}) {
    foreach my $cmd (@{$self->{'init-commands'}}) {
      $self->sendCommand($cmd);
    }
  }

  # Retrieve all the current state of the power supply
  my ($vset) = $self->sendCommand($self->voltageSetpointCommand());
  my ($iset) = $self->sendCommand($self->currentSetpointCommand());
  my ($on) = $self->sendCommand($self->onOffCommand());
  $on = ($on eq 'ON') ? 1 : 0;
  my ($volts, $amps) = $self->_poll;

  return ($vset, $iset, $on, $volts, $amps);
}

=head2 initializeConnection

Initialize the connection to the power supply by creating a suitable helper object.

This method can also implement any other subclass specific setup that may be needed in addition to
the basic initialization steps. This method is called prior to any init-commands included in the config.

=over

=item Return Value

A reference to an object implementing the Milton::Interface::IOHelper interface if successful, otherwise undef.

=back

=cut

sub initializeConnection {
  my ($self) = @_;

  croak ref($self) .": initializeConnection method not implemented";
}

=head2 identify($helper)

Identify the power supply by sending the *IDN? command to the power supply.

This method should is used by the IOHelper classes when verifying the identity of the instrument connected to a
given device file as part of the creation of that helper object. This implementation should be sufficient for
most subclass implementations so you are strongly advised to not override this method.

Note that the meaning of the return value of this method is inverted. If the identification is successful, then
the method returns undef. If identification fails, the return value will be an error message identifying why the
identification failed.

=over

=item $helper

A reference to the Milton::Interface::IOHelper object that is currently attempting to connect to the correct
power supply. This help object should be used for any requests to be sent to the power supply, as this instance's
helper object is likely not yet set, so attempting to send requests without using this helper will likely fail.

=item Return Value

undef if the identification is successful, otherwise a string detailing why the identification was failed.

=back

=cut

sub identify {
  my ($self, $helper) = @_;

  my ($make, $model, $serialNumber, $firmware) = $self->sendCommand('*IDN?', $helper);
  my $id = "$make $model $serialNumber $firmware";
  $id =~ s/\s*$//;

  if ($self->{'id-pattern-re'}) {
    if ($id !~ $self->{'id-pattern-re'}) {
      $id ||= '<<unknown>>';
      return "Device $id does not match pattern $self->{'id-pattern'}";
    }
  } # else just accept it if we have no pattern for identification purposes

  $self->{'id-string'} = $id;
  $self->info("Connected to $id on $helper->{'connected-device'}") if $id;

  return;
}

sub deviceName {
  my ($self) = @_;

  return "$self->{make} $self->{model}";
}

sub sendCommand {
  my ($self, $command, $helper) = @_;

  $helper //= $self->{helper};

  # Maybe should croak?
  return unless $helper;

  $self->debug('Sending SCPI Command: %s', $command) if DEBUG_LEVEL >= REQUEST_DEBUG;
  my $response = $helper->sendRequest("$command\n");
  chomp $response;
  $self->debug('Received SCPI Response: %s', $response) if DEBUG_LEVEL >= RESPONSE_DEBUG;

  # Remove trailing whitespace from the response
  $response =~ s/\s*$//;
  if (defined($response) && $response ne '') {
    return split(/\s*,\s*/, $response);
  }

  return; 
}

sub voltageSetpointCommand {
  my ($self) = @_;
  return $self->{'voltage-setpoint-command'} // 'VOLT?';
}

sub currentSetpointCommand {
  my ($self) = @_;
  return $self->{'current-setpoint-command'} // 'CURR?';
}

sub getIdentityCommand {
  my ($self) = @_;
  return $self->{'get-identity-command'} // '*IDN?';
}

sub setVoltageCommand {
  my ($self, $volts) = @_;
  my $vcmd = $self->{'set-voltage-command'} // 'VOLT';
  my $vfmt = $self->{'voltage-format'} // '.2f';
  return sprintf("%s %$vfmt", $vcmd, $volts);
}

sub _setVoltage {
  my ($self, $volts, $recommendedAmps) = @_;
  my $cmdLen = $self->{'command-length'};
  my $iset = undef;
  my $out_on = undef;

  my $cmd = $self->setVoltageCommand($volts);
  $cmdLen = $cmdLen - length($cmd) - 1;

  if ($recommendedAmps > 0) {
    my $icmd = $self->setCurrentCommand($recommendedAmps);

    if (length($icmd) <= $cmdLen) {
      $cmd = "$cmd;$icmd";
      $cmdLen = $cmdLen - length($icmd) - 1;
    }
  }

  my $oncmd = $self->onOffCommand(1);
  if (length($oncmd) <= $cmdLen) {
    $cmd = "$cmd;$oncmd";
    $cmdLen = $cmdLen - length($oncmd) - 1;
    $out_on = 1;
  }

  # Only single SCPI commands, so can only set volts
  $self->sendCommand($cmd);

  return (1, $out_on, $iset);
}

sub setCurrentCommand {
  my ($self, $amps) = @_;
  my $icmd = $self->{'set-current-command'} // 'CURR';
  my $ifmt = $self->{'current-format'} // '.3f';

  return sprintf("%s %$ifmt", $icmd, $amps);
}

sub _setCurrent {
  my ($self, $amps, $recommendedVolts) = @_;
  my $cmdLen = $self->{'command-length'};
  my $vset = undef;
  my $out_on = undef;

  my $cmd = $self->setCurrentCommand($amps);
  $cmdLen = $cmdLen - length($cmd) - 1;

  if ($recommendedVolts > 0) {
    my $vcmd = $self->setVoltageCommand($recommendedVolts);
    if (length($vcmd) <= $cmdLen) {
      $cmd = "$cmd;$vcmd";
      $cmdLen = $cmdLen - length($vcmd) - 1;
    }
  }

  my $oncmd = $self->onOffCommand(1);
  if (length($oncmd) <= $cmdLen) {
    $cmd = "$cmd;$oncmd";
    $cmdLen = $cmdLen - length($oncmd) - 1;
    $out_on = 1;
  }

  $self->sendCommand($cmd);
  return (1, $out_on, $vset);
}

sub getOutputCommand {
  my ($self) = @_;

  return $self->{'get-output-command'} // 'MEAS:ALL?';
}

sub _poll {
  my ($self) = @_;

  my ($volts, $amps, $power) = $self->sendCommand($self->getOutputCommand());

  return ($volts, $amps);
}

sub onOffCommand {
  my ($self, $on) = @_;
  my $ocmd = $self->{'on-off-command'} // 'OUTP';

  if (!defined $on) {
    return "$ocmd?";
  }

  return $ocmd .' '. ($on && uc($on) ne 'OFF' ? 'ON' : 'OFF');
}

sub _on {
  my ($self, $on) = @_;

  $self->sendCommand($self->onOffCommand($on || 0));

  return (1);
}

sub _disconnect {
  my ($self) = @_;

  if ($self->{helper}) {
    $self->debug('Turning off output') if DEBUG_LEVEL >= CONNECTION_DEBUG;
    $self->_on(0);

    if ($self->{'shutdown-commands'}) {
      $self->debug('Sending shutdown commands') if DEBUG_LEVEL >= CONNECTION_DEBUG;
      foreach my $cmd (@{$self->{'shutdown-commands'}}) {
        $self->sendCommand($cmd);
      }
    }

    $self->debug('Disconnecting from power supply') if DEBUG_LEVEL >= CONNECTION_DEBUG;
    $self->{helper}->disconnect;
  }

  delete $self->{helper};

  return;
}

=head1 AUTHOR Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

1;