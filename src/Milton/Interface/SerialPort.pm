package Milton::Interface::SerialPort;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface);
use Device::SerialPort;
use Carp qw(croak);
use Milton::Interface::Utils::Common qw(device_compare port_exists);

sub new {
  my ($class, $config) = @_;

  my $self = $class->SUPER::new($config);
}

sub checkPortAccessibility {
  my ($self, $port) = @_;

  if (! -r $port) {
    my $ls = `ls -l $port`;
    chomp $ls;
    $self->warning("Port $port is not readable: $ls");

    # Try to suggest corrective action.
    my $permissions = (stat($port))[2] & 07777;
    my $gid = (stat($port))[5];

    if ($permissions & 0040) {
      my $group = getgrgid($gid);
      my $user = getlogin || getpwuid($<);
      $self->info("You may need to add your user to the $group group. Try running sudo usermod -aG $group $user");
    }
    return;
  }

  return 1;
}

sub _connect {
  my ($self) = @_;

  $self->{baudrate} //= 9600;
  $self->{databits} //= 8;
  $self->{parity} //= 'none';
  $self->{stopbits} //= 1;
  $self->{'char-timeout'} //= 1;
  $self->{'response-timeout'} //= 10;

  croak ref($self) .': port must be specified.' if ! defined($self->{port});

  my @ports = glob($self->{port});
  if (scalar(@ports) == 0) {
    croak ref($self) .': could not find any serial ports matching ' . $self->{port};
  }

  @ports = sort { device_compare($a, $b) } @ports;

  foreach my $port (@ports) {
    next if !port_exists($port);

    next if !$self->checkPortAccessibility($port);

    $self->info("Connecting to $port");
    my $serial = undef;
    eval {
      $serial = Device::SerialPort->new($port);
    };
    
    if ($serial) {
      $serial->baudrate($self->{baudrate});
      $serial->databits($self->{databits});
      $serial->parity($self->{parity});
      $serial->stopbits($self->{stopbits});
      $serial->read_char_time($self->{'char-timeout'});
      $serial->read_const_time($self->{'response-timeout'});

      $self->{serial} = $serial;
      if ($self->_identify) {
        $self->{'connected-port'} = $port;
        return $self->_initialize;
      }

      # Clean up open serial port object.
      $serial->close();
      delete $self->{serial};
      $serial = undef;
    }
  }

  die ref($self) .': '. $self->identifyFailedMessage ."\n";
}

sub identifyFailedMessage {
  my ($self) = @_;
  return "could not identify matching power supply connected to $self->{port} at $self->{baudrate} baud";
}

# Default implementation returns TRUE, so that subclasses that do not support scanning multiple ports can still work.
sub _identify {
  return 1;
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