package Milton::Interface::SerialPort;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface);
use Device::SerialPort;
use Carp qw(croak);

sub new {
  my ($class, $config) = @_;

  my $self = $class->SUPER::new($config);
}

sub _connect {
  my ($self) = @_;

  my $port = $self->{port} || croak ref($self) .': port must be specified.';
  $self->info("Connecting to $port");
  my $serial = Device::SerialPort->new($port) || croak ref($self) .': could not open serial port ' . $port . ': ' . $!;

  $self->{baudrate} //= 9600;
  $self->{databits} //= 8;
  $self->{parity} //= 'none';
  $self->{stopbits} //= 1;
  $self->{'char-timeout'} //= 1;
  $self->{'response-timeout'} //= 10;

  $serial->baudrate($self->{baudrate});
  $serial->databits($self->{databits});
  $serial->parity($self->{parity});
  $serial->stopbits($self->{stopbits});
  $serial->read_char_time($self->{'char-timeout'});
  $serial->read_const_time($self->{'response-timeout'});

  $self->{serial} = $serial;

  return $self->_initialize;
}

sub _initialize {
  return;
}

sub _disconnect {
  my ($self) = @_;

  if ($self->{serial}) {
    $self->on(0);

    $self->{serial}->close();
    $self->{serial} = undef;
  }

  return $self;
}

1;