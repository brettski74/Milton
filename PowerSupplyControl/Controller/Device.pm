package PowerSupplyControl::Controller::Device;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use base qw(Exporter);

=head1 NAME

PowerSupplyControl::Controller::Device - A base class for external measurement devices.

=head1 SYNOPSIS

  use PowerSupplyControl::Controller::Device;

  my $device = PowerSupplyControl::Controller::Device->new();

  $device->startListening();

=head1 DESCRIPTION

This class defines the interface for external measurement devices and specifically the
interface expected for external temperature measurement devices used by the RTDController
class. Implementations may not necessarily subclass this class but must implement the
methods defined here.A

It is expected that most devices will be designed to stream temperature readings to the
computer and that implementation of this interface will create some kind of watcher -
perhaps an IO watcher - to parse these readings and store the latest reading for later
use. It's also possible for implementatons to use a timer watcher to poll the device
periodically, but care should be taken to ensure that the polling interval is very short.
Polling intervals should aim to be in the low 10s of milliseconds or less.

=head1 CONSTRUCTOR

=head2 new($config)

=over

=item $config

A hash reference containing configuration options for the device.

=cut

sub new {
  croak shift .'->new not implemented.';
}

=head1 METHODS

=head2 setLogger($logger)

Set the logger for the device.

=cut

sub setLogger {
  my ($self, $logger) = @_;
  $self->{logger} = $logger;
}

=head2 getTemperature

Get the latest temperature reading from the device.

=over

=item Return Value

The most recent temperature reading in celsius.

=back

=cut

sub getTemperature {
  croak ref(shift) .'->getTemperature not implemented.';
}

=head2 listenNow

Listen for at least one temperature reading from the device and then return.

This is primarily used at startup to get an initial reading from the device prior to starting the main event loop.
Note that this method may start its own event loop and will block until the device has read at least one temperature reading.
If it does start its own event loop, it must not return until its event loop has exited.

=cut

sub listenNow {
  croak ref(shift) .'->listenNow not implemented.';
}

=head2 startListening

Start listening for temperature readings from the device.

This is called during or just prior to the starting of the main event loop and will set up
a watcher to listen for temperature readings from the device.

=cut

sub startListening {
  croak ref(shift) .'->startListening not implemented.';
}

=head2 stopListening

Stop listening for temperature readings from the device.

After this is called, the object will no longer listen for or receive temperature updates from
the device.

=cut

sub stopListening {
  croak ref(shift) .'->stopListening not implemented.';
}

=head2 shutdown

Shutdown the device.

=cut

sub shutdown {
  croak ref(shift) .'->shutdown not implemented.';
}

1;