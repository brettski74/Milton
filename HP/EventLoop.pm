package HP::EventLoop;

use strict;
use AnyEvent;
use EV;
use Carp;
use Term::ReadKey;
use HP::DataLogger;

=head1 NAME

HP::EventLoop - Main event loop environment for the hotplate controller.

=head1 DESCRIPTION

Implement the main event loop environment in which the overall hotplate controller commands can run.

=head2 new($config, @args

Create a new event loop object.

=over

=item $config

The HP:Config object representation the configuration file.

=item $command

The command to be run.

=item @args

A list of arguments passed on the command line to this command.

=back

=cut

sub new {
  my ($class, $config, $command, @args) = @_;
  my $self = { config => $config
             , args => \@args
             , history => []
             };

  bless $self, $class;

  $self->_initializeObject('interface');
  $self->_initializeObject('controller', $self->{interface});

  $self->_initializeCommand($command, @args);

  $self->{logger} = HP::DataLogger->new($self->{config}->clone('logging'), command => $command);

  return $self;
}

=head2 poll

Poll the state of the hotplate.

=over

=item Return Value

The status hash containing current state of the hotplate. Note that this will be bare bones information only. The status object will
be enriched with additional data as processing proceeds.

=cut

sub poll {
  my ($self, $event, @attrs) = @_;

  my $status = $self->{interface}->poll();
  $status->{event} = $event;
  $status->{period} = $self->{config}->{period};

  while (@attrs) {
    my $key = shift @attrs;
    my $val = shift @attrs;
    if (!exists $status->{$key}) {
      $status->{$key} = $val;
    }
  }

  $self->{controller}->getTemperature($status);

  # Make previous values available
  if (exists $self->{'last-timer-status'}) {
    $status->{last} = $self->{'last-timer-status'};

    if ($event eq 'timerEvent') {
      $self->{'last-timer-status'}->{next} = $status;
      $self->{'last-timer-status'} = $status;
    }
  } elsif ($event eq 'timerEvent') {
    $self->{'last-timer-status'} = $status;
  }

  push(@{$self->{history}}, $status);

  return $status;
}

sub _now {
  my ($self) = @_;
  my $now = AnyEvent->now;
  if (!exists $self->{'start-time'}) {
    $self->{'start-time'} = $now;
  }
  return $now - $self->{'start-time'};
}

sub _time {
  my ($self) = @_;

  return AnyEvent->time - $self->{'start-time'};
}

=head2 run

Run the event loop.

=cut

sub _cleanShutdown {
  my $self = shift;

  ReadMode('normal');

  $self->{interface}->shutdown;

  exit(0);
}

sub _keyWatcher {
  my ($self, $evl) = @_;

  my $cmd = $self->{command};

  my $status = { event => 'keyEvent'
               , now => $self->_now
               , time => $self->_time
               };
                                        
  $status->{key} = ReadKey(-1);
                                          
  if (! $cmd->keyEvent($status)) {
    $self->{logger}->log($status);
    $evl->send;
  }
  $self->{logger}->log($status);
}

sub _timerWatcher {
  my ($self, $evl) = @_;

  my $cmd = $self->{command};

  my $status = $self->poll('timerEvent'
                         , now => $self->_now
                         );
  if (! $cmd->timerEvent($status)) {
    $self->{logger}->log($status);
    $evl->send;
  }
  $self->{logger}->log($status);
}

sub run {
  my $self = shift;
  my $cmd = $self->{command};

  if ($cmd->can('preprocess')) {
    my $status = $self->poll('preprocess');
    $cmd->preprocess($status);
    $self->{logger}->log($status);
  }

  if ($cmd->can('timerEvent')) {
    my $evl = AnyEvent->condvar;

    if ($cmd->can('keyEvent')) {
      ReadMode('cbreak');

      $self->{'key-watcher'} = AnyEvent->io(fh => \*STDIN
                                          , poll => 'r'
                                          , cb => sub {
                                            $self->_keyWatcher($evl);
                                          });
    }

    $self->{'timer-watcher'} = AnyEvent->timer(interval => $self->{config}->{period}
                                             , cb => sub {
                                                $self->_timerWatcher($evl);
                                             });

    my $int_watcher = AnyEvent->signal(signal => 'INT', cb => sub { $self->_cleanShutdown });
    my $term_watcher = AnyEvent->signal(signal => 'TERM', cb => sub { $self->_cleanShutdown });
    my $quit_watcher = AnyEvent->signal(signal => 'QUIT', cb => sub { $self->_cleanShutdown });

    $evl->recv;

    $self->_cleanShutdown;
  }

  if ($cmd->can('postprocess')) {
    my $status = $self->poll('postprocess');
    $cmd->postprocess($status, $self->{history});
    $self->{logger}->log($status);
  }
}

sub _initializeObject {
  my ($self, $key, @args) = @_;

  my $package = $self->{config}->{$key}->{package};

  eval "use $package";
  
  if ($@) {
    croak "Failed to load $key package: $@";
  }

  $self->{$key} = $package->new($self->{config}->clone($key), @args);

  return;
}

sub _initializeCommand {
  my ($self, $command, @args) = @_;

  my $cmd_pkg = "HP::Command::$command";
  eval "use $cmd_pkg";

  if ($@) {
    croak "Failed to load $cmd_pkg: $@";
  }

  $self->{command} = $cmd_pkg->new($self->{config}->clone('command', $command), $self->{controller}, $self->{interface}, @args);
}

1;