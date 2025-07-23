package BLE::BlueToothCtl;

use strict;
use warnings qw(all -uninitialized);
use IO::Pipe;
use Carp qw(croak);

# I know I hate use constant, but this is referenced in a destructor and for some reason
# The $TIMEOUT variable is always garbage collected before the device object! So maybe
# this will shut it up!
use constant TIMEOUT => 30;

sub new {
    my ($class, %config) = @_;

    my $send = IO::Pipe->new;
    my $recv = IO::Pipe->new;
    my $pid = fork;

    if ($pid) {
      # parent process
      $send->writer;
      $recv->reader;
    } elsif (defined $pid) {
      # child process
      $send->reader;
      $recv->writer;

      open STDIN, '<&', $send;
      open STDOUT, '>&', $recv;

      exec 'bluetoothctl';
      die "exec failed: $!";
    } else {
      croak "fork failed: $!";
    }

    $send->autoflush(1);
    $recv->autoflush(1);
    $recv->blocking(0);

    my $self = { send => $send
               , recv => $recv
               , pid => $pid
               };

    bless $self, $class;

    $self->debug($config{'debug'}) if $config{'debug'};

    # Make sure we're disconnected
    $self->disconnect;

    return $self;
}

sub debug {
  my ($self, $onoff) = @_;

  $self->{debug} = $onoff;
}

sub connect {
  my ($self, $pattern, $timeout) = @_;
  $timeout //= TIMEOUT;
  $self->send('power on', qr/Changing power on/);
  $self->send('agent on', qr/Agent.*registered/);
  $self->send('scan off');
  $self->send('menu scan');
  $self->send('transport le');
  $self->send('back', qr/Run script/);
  $self->send('scan on');

  my $device;
  while ($timeout && !defined $device) {
    ($device) = $self->waitFor(qr/Device ([0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5})/, \$timeout);
    if ($device && $device !~ $pattern) {
      $device = undef;
    }
  }

  if (!$device) {
    croak "Timeout connecting to BLE device $pattern";
  }

  $self->send("connect $device", qr/Connection successful|Device not available|Connection already established/, \$timeout);
  $self->{device} = $device;
  $self->send('scan off', qr/Discovery/);

  return $self;
}

sub disconnect {
  my $self = shift;
  my $retries = 3;
  while ($retries--) {
    my ($response) = $self->send('disconnect', qr/Disconnection successful|Missing device address argument|Invalid command in menu/);

    if ($response !~ /Invalid command in menu/) {
      last;
    } else {
      $self->send('back', qr/Run script/);
    }
  }

  delete $self->{device};

  return $self;
}

sub isConnected {
  my ($self) = @_;

  return $self->{device};
}

sub isSubscribed {
  my ($self) = @_;

  return $self->{attribute};
}

sub shutdown {
  my ($self) = @_;

  if ($self->{send}) {
    $self->disconnect;
  }

  if ($self->{pid}) {
    kill 'TERM', $self->{pid};
    waitpid $self->{pid}, 0;
  }

  if ($self->{send}) {
    $self->{send}->close;
    $self->{recv}->close;
  }

  delete $self->{send};
  delete $self->{recv};
  delete $self->{pid};

  return $self;
}

sub DESTROY {
  my $self = shift;
  $self->shutdown;
}

sub subscribe {
  my ($self, $attribute, $match, $timeout) = @_;
  $timeout //= TIMEOUT;

  $match //= $attribute;

  $self->send('menu gatt', qr/Run script/);
#  $self->send("list-attributes $self->{device}", qr/$attribute/);
  my @rc = $self->send("select-attribute $attribute", qr/$match/);

  if (@rc) {
    $self->{attribute} = $match;
  }

  return 1 if @rc;
  return;
}

sub send {
  my ($self, $command, $expect, $timeout) = @_;

  return if !defined($self->{send});

  $timeout //= TIMEOUT;

  $self->{send}->print("$command\n");
#  if ($self->{debug}) {
#    print "send: $command\n";
#  }

  if ($expect) {
    return $self->waitFor($expect, $timeout);
  }

  $self->clearInputBuffer;

  return 1;
}

sub clearInputBuffer {
  my ($self) = @_;

  while (my $line = $self->{recv}->getline) {
    chomp $line;
#    if ($self->{debug}) {
#      print "recv: $line\n";
#    }
  }
}

sub waitFor {
  my ($self, $expect, $timeout) = @_;
  $timeout //= TIMEOUT;
  
  # if the caller passed in a reference to a timeout, we'll update it
  my $timeout_ref;
  if (ref $timeout) {
    $timeout_ref = $timeout;
    $timeout = $$timeout_ref;
  }

  while ($timeout--) {
    while (my $line = $self->{recv}->getline) {
      chomp $line;
#      if ($self->{debug}) {
#        print "recv: $line\n";
#      }
      my @rc = $line =~ $expect;
      if (@rc) {
        if ($timeout_ref) {
          $$timeout_ref = $timeout;
        }
        return @rc;
      }
    }

    sleep 1;
  }

  if ($timeout_ref) {
    $$timeout_ref = 0;
  }

  return;
}

1;