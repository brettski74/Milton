package Milton::Interface::FilehandleHelper;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface::IOHelper);
use Carp qw(croak);
use Milton::Interface::IOHelper qw(device_compare);

sub new {
  my ($class, $config) = @_;

  my $self = { device => $config->{device} };

  return $class->SUPER::new($self);
}

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

  return unless $in && $out;  ### Burger! Actually, they're quite ordinary, IMHO!

  $in->print($request);

  # Hopefully we never end up with fragmentation. If we go, getline may be an option, but also comes with some caveats,
  # such as what if we ever have a multi-line response from some kind of request? Hoping that this was the more future-
  # proof decision.
  $out->read($buffer, 255);

  return $buffer;
}

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

sub DESTROY {
  my ($self) = @_;

  $self->disconnect;

  return $self->SUPER::DESTROY;
}

1;