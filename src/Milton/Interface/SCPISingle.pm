package Milton::Interface::SCPISingle;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Interface::SerialPort);
use Carp qw(croak);

=head1 NAME

Milton::Interface::SCPISingle - SCPISingle interface

=head1 SYNOPSIS

=head1 DESCRIPTION

Implement a power supply interface based on SCPI commands that does not support multiple command string,
such as many devices in the Uni-T UDP6700 series of power supplies. Check the programming manual for you
device for exact details. Some products like the UDP6722 appear to support multiple command strings, but
my UDP6721 does not, so we need to send a single SCPI command per line and wait for the response before
we can send the next command.

This class uses the following SCPI commands and so should work with any SCPI power supply that supports
these commands:

=over

=item *IDN?

The identification query command. Retrieves device information such as model number, serial number and firmware version.

=item MEASure:ALL?

Queries the power supply for voltage, current and power values. Expects a response with 3 numbers - voltage, current and power, in that order.

=item SOURce:VOLTage?

Queries the power supply for the voltage set point.

=item SOURce:CURRent?

Queries the power supply for the current set point.

=item SOURce:VOLTage <voltage>

Sets the voltage set point.

=item SOURce:CURRent <current>

Sets the current set point.

=item OUTPut

Sets the output on or off.

=item OUTPut?

Queries the power supply for the state of the output (ie. on or off).

=item SYSTem:REMote

Put the power supply in remote mode. This essentially locks the keypad on the power supply to prevent inadvertent changes to settings while a command is running.

=item SYSTem:REMote?

Queries the power supply as to whether it is in remote mode.

=back

=head1 CONSTRUCTOR

=head2 new($config)

Create a new SCPISingle interface.

=over

=item $config

A reference to a hash of named configuration parameters. The following parameters are supported by this class,
in addition to those supported by the Milton::Interface class, from  which it is descended.

=over

=item port

The device name of the serial port to use to connect to the power supply.

=item baudrate

The baud rate to use to connect to the power supply. If not specified, the default baud rate of 9600 is used.

=item databits

The number of serial data bits per byte to use when communicating over RS232 with the power supply.
If not specified, the default of 8 is used.

=item parity

The parity bit to use when communicating over RS232 with the power supply. If not specified, the default of 'none' is used.

=item stopbits

The number of serial stop bits per byte to use when communicating over RS232 with the power supply.
If not specified, the default of 1 is used.

=item handshake

What type of hardware flow control to use, if any. If not specified, the default of 'none' is used.

=item char-timeout

The inter-character timeout in either milliseconds or deciseconds depending on who you ask.
It specifies the timeout to use when reading responses from the power supply.  The underlying serial
communications stack will wait this long after reading a byte for the next byte to start. If nothing
arrives in that time, it assumes that the response is complete and returned what was read. We should
keep this low to avoid blocking too long when reading responses.
The default value of 1 should be sufficient for most needs.

=item response-timeout

The total timeout in (possibly?) milliseconds to use when reading responses from the power supply. This
controls the maximum amount of time that the serial stack will wait for a response from the power supply.
Again, keep this low to prevent long blocking delays when reading responses.
The default value of 10 should be sufficient for most needs.

=back

=cut

sub new {
  my ($class, $config) = @_;

  $config->{baudrate} //= 9600;
  $config->{databits} //= 8;
  $config->{parity} //= 'none';
  $config->{stopbits} //= 1;
  $config->{handshake} //= 'none';
  $config->{'char-timeout'} //= 1;
  $config->{'response-timeout'} //= 10;

  my $self = $class->SUPER::new($config);

  return $self;
}

#sub _connect {
#  my ($self) = @_;

#  my $port = $self->{port} || croak ref($self) .': port must be specified.';
#  $self->info("Connecting to $port");
#  my $serial = Device::SerialPort->new($port) || croak ref($self) .': could not open serial port ' . $port . ': ' . $!;

#  $serial->baudrate($self->{'baudrate'});
#  $serial->databits($self->{'databits'});
#  $serial->parity($self->{'parity'});
#  $serial->stopbits($self->{'stopbits'});
#  $serial->handshake($self->{'handshake'});
#  $serial->read_char_time($self->{'char-timeout'});
#  $serial->read_const_time($self->{'response-timeout'});

#  $self->{serial} = $serial;

sub _initialize {
  my ($self) = @_;

  ($self->{make}, $self->{model}, $self->{'serial-number'}, $self->{firmware}) = $self->_sendCommand('*IDN?');
  croak ref($self) .": could not get device information from $self->{port}: $!" if !defined($self->{make});

  my ($vset) = $self->_sendCommand('SOUR:VOLT?');
  my ($iset) = $self->_sendCommand('SOUR:CURR?');
  my ($on) = $self->_sendCommand('OUTP?');
  $on = ($on eq 'ON') ? 1 : 0;
  my ($volts, $amps, $power) = $self->_sendCommand('MEAS:ALL?');

  $self->info("Connected to $self->{make} $self->{model} $self->{'serial-number'} $self->{firmware} on $self->{port}");

  return ($vset, $iset, $on, $volts, $amps);
}

sub deviceName {
  my ($self) = @_;

  return "$self->{make} $self->{model}";
}

#sub _disconnect {
#  my ($self) = @_;

#  if ($self->{serial}) {
#    $self->on(0);

#    $self->{serial}->close();
#    $self->{serial} = undef;
#  }

#  return $self;
#}

sub _sendCommand {
  my ($self, $command) = @_;
  my $serial = $self->{serial};
  return unless $serial;

  $serial->write("$command\n");
  my $response = $serial->read(255);
  chomp $response;

  if (defined($response) && $response ne '') {
    return split(/\s*,\s*/, $response);
  }

  return;
}

sub _setVoltage {
  my ($self, $volts, $recommendedAmps) = @_;

  # Only single SCPI commands, so can only set volts
  $self->_sendCommand(sprintf('SOUR:VOLT %.2f', $volts));

  return (1);
}

sub _setCurrent {
  my ($self, $amps, $recommendedVolts) = @_;

  # Only single SCPI commands, so can only set amps
  $self->_sendCommand(sprintf('SOUR:CURR %.3f', $amps));

  return (1);
}

sub _poll {
  my ($self) = @_;

  my ($volts, $amps, $power) = $self->_sendCommand('MEAS:ALL?');

  return ($volts, $amps);
}

sub _on {
  my ($self, $on) = @_;

  $self->_sendCommand('OUTP '. ($on ? 'ON' : 'OFF'));

  return (1);
}

1;