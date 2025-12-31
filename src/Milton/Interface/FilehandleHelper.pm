package Milton::Interface::FilehandleHelper;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface::IOHelper);
use IO::File;
use Carp qw(croak);
use Milton::Interface::IOHelper qw(device_compare);

=head1 NAME

Milton::Interface::FilehandleHelper - IOHelper implementation using a pair of read/write filehandles and sysread/syswrite calls

=head1 DESCRIPTION

An implementation of the IOHelper interface that uses a pair of read and write filehandles to communicate with
the instrument using sysread and syswrite calls. This was originally written to support communicating with USBTMC
devices, but could potentially be used for any instrument that simply requires writing to and reading from a
character device file.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new Milton::Interface::FilehandleHelper object.

=over

=item $config

A reference to a hash of named configuration parameters. The only named parameter that is supported by this class
at this time is the device parameter, as described in the Milton::Interface::IOHelper interface.

=back

=cut

sub new {
  my ($class, $config) = @_;

  my $self = { device => $config->{device}
             , logger => $config->{logger}
             };

  return $class->SUPER::new($self);
}

=head2 tryConnection($device)

Try to connect to the device. This method simply opens a read filehandle and a write filehandle on the device
and returns true if both are successful, otherwise returns false.

=over

=item $device

The path to the device to try to connect to.

=item Return Value

Returns true if the connection is successful, otherwise returns false.

=back

=cut

sub tryConnection {
  my ($self, $device) = @_;

  croak ref($self) .": Already connected." if $self->{in};

  eval {
    $self->{in} = IO::File->new($device, 'r');
    $self->{out} = IO::File->new($device, 'w');
  };

  return $self->{in} && $self->{out};
}

sub sendRequest {
  my ($self, $request) = @_;
  my $in = $self->{in};
  my $out = $self->{out};
  my $buffer;
  my $len;

  return unless $in && $out;  ### Burger! Actually, they're quite ordinary, IMHO!

  $out->syswrite($request);

  # Hopefully we never end up with fragmentation. If we go, getline may be an option, but also comes with some caveats,
  # such as what if we ever have a multi-line response from some kind of request? Hoping that this was the more future-
  # proof decision.
  $len = $in->sysread($buffer, 255);

  return $buffer;
}

=head2 disconnect()

Disconnect from the instrument. This method checks for the presence of the read and write filehandles, closes them if
present and then removes the references to them.

=over

=item Return Value

Returns a reference to this IOHelper object, to allow for chaining of methods.

=back

=cut

sub disconnect {
  my ($self) = @_;

  if ($self->{in}) {
    $self->{in}->close();
  }

  if ($self->{out}) {
    $self->{out}->close();
  }

  delete $self->{in};
  delete $self->{out};

  $self->SUPER::disconnect;

  return $self;
}

1;
