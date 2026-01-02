package Milton::Interface::SerialPortHelper;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface::IOHelper);
use Device::SerialPort;
use Carp qw(croak);
use Path::Tiny qw(path);
use Milton::Interface::IOHelper qw(device_compare);

use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEVICE_DEBUG => 20;

use Exporter qw(import);
our @EXPORT_OK = qw(serial_port_exists);

=head1 NAME

Milton::Interface::SerialPortHelper - IOHelper implementation for serial interfaces

=head1 DESCRIPTION

An implementation of the IOHelper interface that uses a serial port to communicate with the instrument.
This may be RS-232 serial, USB serial or any other type of serial port compatible with the Device::SerialPort
module.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new Milton::Interface::SerialPortHelper object.

=over

=item $config

A reference to a hash of named configuration parameters. The following parameters are supported by this class,
in addition to those supported by the Milton::Interface::IOHelper class (ie. device).

=over

=item baudrate

The baud rate to use to connect to the instrument. If not specified, the default of 9600 is used.

=item databits

The number of data bits to use when communicating with the instrument. If not specified, the default of 8 is used.

=item parity

The parity bit to use when communicating with the instrument. If not specified, the default of 'none' is used.

=item stopbits

The number of stop bits to use when communicating with the instrument. If not specified, the default of 1 is used.

=item char-timeout

The character timeout to use when communicating with the instrument. If not specified, the default of 1 is used.

=item response-timeout

The response timeout to use when communicating with the instrument. If not specified, the default of 10 is used.

=back

=cut

sub new {
  my ($class, $config) = @_;

  my $self = { baudrate => $config->{baudrate} // 9600
             , databits => $config->{databits} // 8
             , parity => $config->{parity} // 'none'
             , stopbits => $config->{stopbits} // 1
             , 'char-timeout' => $config->{'char-timeout'} // 1
             , 'response-timeout' => $config->{'response-timeout'} // 10
             , device => $config->{device}
             , logger => $config->{logger}
             };

  return $class->SUPER::new($self);
}

=head2 serial_port_exists($port)

Utility function to check if a serial port exists.

USB Serial ports are typically created by udev upon detection by the kernel, but RS-232 devices are
usually created statically by most Linux distributions regardless of whether or not the hardward for
them actually is present. This function attempts to verify that the device exists and refers to
physically present hardware on the system. It performs the following checks:

=over

1. Verify that the device file exists.

2. For /dev/ttyS* devices, verify that the /sys/class/tty/$port/device/driver directory exists.

3. For /dev/ttyS* devices, verify that the /sys/class/tty/$port/irq file exists and contains a non-zero value.

=back

If all checks are successful, the function returns true, otherwise the port is considered non-existent and
the function returns false.

=over

=item $port

The path to the serial port to check. (eg. /dev/ttyS1, /dev/ttyUSB0, /dev/ttyACM0, etc)

=item Return Value

Returns true if the serial port exists, otherwise returns false.

=back

=cut

sub serial_port_exists {
  my ($port) = @_;

  if (-e $port) {
    # Get the major device number for the port.
    my $major = ((stat($port))[6] & 0xff00) >> 8;

    # Standard serial devices are major device number 4.
    if ($major == 4) {
      my $fh = IO::File->new($port, 'r');
      my $ok = undef;
      if ($fh) {
        my $tty = POSIX::Termios->new();
        $ok = $tty->getattr($fh->fileno);
        $fh->close;
      }

      return if !$ok;
    }

    # No reason to doubt it, so assume it's good.
    return 1;
  }

  # Device file doesn't exist, so no bueno.
  return;
}

=head2 validateDevice($device)

Utility function to validate a serial port device. In addition to calling the superclass
validateDevice method, it also calls the serial_port_exists function to verify that the
serial port is present.

=over

=item $device

The path to the serial port to validate.

=item Return Value

Returns true if the serial port is valid, otherwise returns false.

=back

=cut

sub validateDevice {
  my ($self, $device) = @_;

  return if !serial_port_exists($device);
  return if !$self->SUPER::validateDevice($device);

  return 1;
}

=head2 tryConnection($device) 

Try to connect to the serial port. This method creates a new Device::SerialPort object and configures it
with the baud rate, data bits, parity, stop bits, character timeout and response timeout specified in the
configuration.

=over

=item $device

The path to the serial port to try to connect to.

=item Return Value

Returns true if the connection is successful, otherwise returns false.

=back

=cut

sub tryConnection {
  my ($self, $device) = @_;

  croak ref($self) .": Already connected." if $self->{serial};

  Device::SerialPort::nocarp;

  eval {
    my $serial = Device::SerialPort->new($device);

    $serial->baudrate($self->{baudrate});
    $serial->databits($self->{databits});
    $serial->parity($self->{parity});
    $serial->stopbits($self->{stopbits});
    $serial->read_char_time($self->{'char-timeout'});
    $serial->read_const_time($self->{'response-timeout'});

    $self->{serial} = $serial;
  };

  return $self->{serial};
}

=head2 sendRequest($request)

Send a request to the serial port and return the response.

=over

=item $request

The request to send to the serial port.

=item Return Value

The response from the serial port.

=back

=cut

sub sendRequest {
  my ($self, $request) = @_;
  my $serial = $self->{serial};
  return unless $serial;

  $serial->write($request);
  my $response = $serial->read(255);

  return $response;
}

=head2 disconnect()

Disconnect from the serial port. This method checks for the presence of the serial port object, closes it if
present and then removes the reference to it.

=over

=item Return Value

Returns a reference to this IOHelper object, to allow for chaining of methods.

=back

=cut

sub disconnect {
  my ($self) = @_;

  if ($self->{serial}) {
    $self->{serial}->close();
  }

  delete $self->{serial};
  $self->SUPER::disconnect;

  return $self;
}

1;