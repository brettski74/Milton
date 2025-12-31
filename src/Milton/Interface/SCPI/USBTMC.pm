package Milton::Interface::SCPI::USBTMC;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Interface::SCPICommon);
use Carp qw(croak);
use Milton::Interface::FilehandleHelper;

=head1 NAME

Milton::Interface::SCPI::USBTMC - SCPI Implementation over the USB Test and Measurement Class (TMC) protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

Implement a power supply interface based on SCPI commands and using the USB Test and Measurement Class (TMC) protocol
for the transport.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new Milton::Interface::SCPI::USBTMC object.

=over

=item $config

A reference to a hash of named configuration parameters. The following parameters are supported by this class,
in addition to those supported by the Milton::Interface::SCPICommon class, from which it is descended.

=over

=item device

The device name of the USBTMC device to use to connect to the power supply. This may be a glob pattern to specify
multiple devices to try. The correct device will be identified based on the id-pattern which should be specified in
the configuration whenever a glob pattern is used.

=back

=cut

sub initializeConnection {
  my ($self) = @_;

  my $helper = Milton::Interface::FilehandleHelper->new($self);

  return $helper->connect($self);
}

1;