package Milton::Controller::Device::BinarySerial;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Controller::Device);
use Carp qw(croak);
use Milton::Interface::SerialPortHelper;
use AnyEvent;

sub new {
  my ($class, %options) = @_;

  my $self = \%options;

  if (ref($options{handler}) eq 'CODE') {
    $self->{handler} = $options{handler};
  }
  $self->{buffer} = '';
  $self->{bufpos} = 0;
  $self->{buflen} = 0;

  bless $self, $class;

  return $self;
}

sub readDevice {
  croak ref(shift) .'->readDevice not implemented.';
}

sub readBuffer {
  my $self = shift;
  my $helper = shift // $self->{helper};

  return if !$helper;

  my $serial = $helper->get_serial_port;
  my ($count, $chars) = $serial->read(255);
  $self->{buflen} += $count;
  $self->{buffer} .= $chars;

  return $count;
}

sub lookfor {
  my ($self, $char) = @_;
  my $buflen = $self->{buflen};

  while ($self->{bufpos} < $buflen) {
    if (substr($self->{buffer}, $self->{bufpos}, 1) eq $char) {
      return 1;
    }
    $self->{bufpos}++;
  }

  $self->{buffer} = '';
  $self->{bufpos} = 0;
  $self->{buflen} = 0;

  return;
}

sub bufferLength {
  my ($self) = @_;
  return $self->{buflen} - $self->{bufpos};
}

sub readChars {
  my ($self, $count) = @_;
  
  my $result = substr($self->{buffer}, $self->{bufpos}, $count);
  $self->{bufpos} += $count;

  if ($self->{bufpos} >= $self->{buflen}) {
    # Truncate the buffer
    $self->{buffer} = '';
    $self->{buflen} = 0;
    $self->{bufpos} = 0;
  }

  return $result;
}

sub truncateBuffer {
  my ($self) = @_;

  $self->{buffer} = substr($self->{buffer}, $self->{bufpos});
  $self->{buflen} -= $self->{bufpos};
  $self->{bufpos} = 0;
}

sub drainBuffer {
  my ($self) = @_;

  $self->{buffer} = '';
  $self->{buflen} = $self->{bufpos} = 0;
}

sub readByte {
  my ($self) = @_;

  if ($self->{bufpos} < $self->{buflen}) {
    my $rc = ord(substr($self->{buffer}, $self->{bufpos}++, 1));
    $self->drainBuffer if $self->{bufpos} >= $self->{buflen};
    return $rc;
  }

  $self->drainBuffer if $self->{buflen} > 0;

  return;
}

sub skipChars {
  my ($self, $count) = @_;

  $self->{bufpos} += $count;
  
  if ($self->{bufpos} >= $self->{buflen}) {
    $self->{buffer} = '';
    $self->{buflen} = 0;
    $self->{bufpos} = 0;
  }
}

sub identify {
  return;
}

sub _connect {
  my ($self) = @_;

  return $self->{helper} if $self->{helper};

  my $helper = Milton::Interface::SerialPortHelper->new($self);
  $self->{helper} = $helper->connect($self);

  return $self->{helper};
}

sub detectDevice {
  croak ref(shift) .'->detectDevice not implemented.';
}

sub startListening {
  my ($self) = @_;
  return if $self->isListening();

  my $helper = $self->_connect;
  return if !$helper;

  $self->{watcher} = AnyEvent->io(fh => $helper->get_fileno, poll => 'r', cb => sub {
    if ($self->readBuffer > 0) {
      my $rc = $self->receiveData;

      if ($rc && ref($self->{handler}) eq 'CODE') {
        $self->{handler}->($self);
      }
    }
  });

  $self->{helper} = $helper;
}

sub isListening {
  my ($self) = @_;
  return 1 if $self->{watcher} && $self->{helper};
  return;
}

sub stopListening {
  my ($self) = @_;
  return unless $self->isListening();

  $self->receiveData;
  $self->{helper}->disconnect();
  delete $self->{helper};
  delete $self->{watcher};
}

sub shutdown {
  my ($self) = @_;

  $self->stopListening;
}

1;
