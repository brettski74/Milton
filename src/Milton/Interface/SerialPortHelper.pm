package Milton::Interface::SerialPortHelper;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface::IOHelper);
use Device::SerialPort;
use Carp qw(croak);
use Path::Tiny qw(path);
use Milton::Interface::IOHelper qw(device_compare);

sub new {
  my ($class, $config) = @_;

  my $self = { baudrate => $config->{baudrate} // 9600
             , databits => $config->{databits} // 8
             , parity => $config->{parity} // 'none'
             , stopbits => $config->{stopbits} // 1
             , 'char-timeout' => $config->{'char-timeout'} // 1
             , 'response-timeout' => $config->{'response-timeout'} // 10
             , device => $config->{device}
             };

  return $class->SUPER::new($self);
}

sub serial_port_exists {
  my ($port) = @_;

  if (-e $port) {
    if ($port =~ /^\/dev\/(ttyS[0-9]+)$/) {
      my $dev = $1;
      if (-d "/sys/class/tty/$dev/device/driver") {
        my $irq_file = path("/sys/class/tty/$dev/irq");
        my $irq = $irq_file->slurp;
        chomp $irq;
        if ($irq > 0) {
          return 1;
        }
      }
      # No driver directory or IRQ is not non-zero, so the port does not exist.
      return;
    }

    # Device file exists and not a standard 16550 UART, so assume it's good.
    return 1;
  }

  # Device file doesn't exist, so no bueno.
  return;
}

sub validateDevice {
  my ($self, $device) = @_;

  return if !serial_port_exists($device);
  return if !$self->SUPER::validateDevice($device);

  return 1;
}

sub tryConnection {
  my ($self, $device) = @_;

  croak ref($self) .": Already connected." if $self->{serial};

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

sub sendRequest {
  my ($self, $request) = @_;
  my $serial = $self->{serial};
  return unless $serial;

  $serial->write($request);
  my $response = $serial->read(255);

  return $response;
}

sub disconnect {
  my ($self) = @_;

  if ($self->{serial}) {
    $self->{serial}->close();
  }

  delete $self->{serial};
  $self->SUPER::disconnect;

  return $self;
}

sub DESTROY {
  my ($self) = @_;

  $self->disconnect;

  return $self->SUPER::DESTROY;
}

1;