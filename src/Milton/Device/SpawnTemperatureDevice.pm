package Milton::Device::SpawnTemperatureDevice;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Device);
use Carp qw(croak);

sub new {
  my ($class, %options) = @_;

  my $self = \%options;

  my $spawn = $self->{spawn};
  my $package = $spawn->{package};
  eval "use $package";
  if ($@) {
    croak "Failed to load package $package: $@";
  }
  $self->{child} = $package->new(logger => $self->{logger}, %$spawn);
  croak "Failed to create child device of class $package" if !$self->{child};

  bless $self, $class;
  $self->info("PID: $$");

  return $self;
}

sub deviceName {
  my ($self) = @_;
  return $self->{child}->deviceName;
}

sub listenNow {
  my ($self) = @_;
  $self->{child}->listenNow;
}

sub getTemperature {
  my ($self) = @_;

  my $child = $self->{child};
  if ($child) {
    return $child->getTemperature;
  }

  return;
}

sub startListening {
  my ($self) = @_;

  return if $self->isListening();

  my $child = $self->{child};

  if ($child->isListening) {
    $child->stopListening;
  }

  my $pipe = IO::Pipe->new;

  my $pid = fork;
  if ($pid) {
    # parent
    $pipe->reader;
    $self->{pid} = $pid;
    $self->{pipe} = $pipe;
    $self->{watcher} = AnyEvent->io(fh => $pipe->fileno, poll => 'r', cb => sub {
      my $line;

      while ($line = $pipe->getline) {
        1;
      }

      chomp $line;
      $self->setTemperature($line + 0);
    });
  } elsif (defined($pid)) {
    # Child
    # Alter process name to more clearly identify the child
    $0 = ref($self);

    # Set up the pipe for writing
    $pipe->writer;
    $pipe->autoflush(1);

    # Set up the child to listen for temperature readings
    $child->startListening;
    $child->setHandler(sub {
      my ($self) = @_;
      $self->info("PID: $$");
      $pipe->print($child->getTemperature ."\n");
    });

    # Cleanly shut down when the pipe is closed
    $SIG{PIPE} = sub {
      $child->stopListening;
      $self->stopListening;
      exit(0);
    };

    # Start our own event loop
    my $condvar = AnyEvent->condvar;
    $condvar->recv;

    # Exit when the event loop exits
    exit(0);
  } else {
    croak "fork failed: $!";
  }

  return;
}

sub isListening {
  my ($self) = @_;

  return defined($self->{pipe});
}

sub stopListening {
  my ($self) = @_;

  return if !$self->isListening();

  $self->{pipe}->close;
  kill 'PIPE', $self->{pid};
  delete $self->{pipe};
  delete $self->{pid};
}

sub shutdown {
  my ($self) = @_;

  $self->stopListening;
}

1;