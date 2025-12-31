package Milton::Interface::SCPI::Serial;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Interface::SCPICommon);
use Carp qw(croak);
use Milton::Interface::SerialPortHelper;

=head1 NAME

Milton::Interface::SCPI::Serial - SCPI Implementation over serial ports

=head1 SYNOPSIS

=head1 DESCRIPTION

Implement a power supply interface based on SCPI commands and using a serial port for the transport.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new Milton::Interface::SCPI::Serial object.

=over

=item $config

A reference to a hash of named configuration parameters. The following parameters are supported by this class,
in addition to those supported by the Milton::Interface::SCPICommon class, from which it is descended.

=over

=item device

The device name of the serial port to use to connect to the power supply. This may be a glob pattern to specify
multiple ports to try. The correct port will be identified based on the id-pattern which should be specified in
the configuration whenever a glob pattern is used.

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

sub initializeConnection {
  my ($self) = @_;

  my $helper = Milton::Interface::SerialPortHelper->new($self);

  return $helper->connect($self);
}

1;