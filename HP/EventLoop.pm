package HP::EventLoop;

use strict;
use AnyEvent;
use EV;
use Carp;
use Term::ReadKey;

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

  $self->_initialize_object('interface');
  $self->_initialize_object('controller');

  my $cmd_pkg = "HP::Command::$command";
  eval {
    use $cmd_pkg;
    $self->{command} = $cmd_pkg->new($self->{config}->clone('command', $command), $self->{interface}, $self->{controller}, @args);
  };

  if ($@) {
    croak "Failed to load $cmd_pkg: $@";
  }

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
  $status->{}

  while (@attrs) {
    my $key = shift @attrs;
    my $val = shift @attrs;
    if (!exists $status->{$key}) {
      $status->{$key} = $val;
    }
  }

  $self->{controller}->getTemperature($status);

  push(@{$self->{history}}, $status);

  return $status;
}

=head2 run

Run the event loop.

=cut

sub _cleanShutdown {
  ReadMode('normal');

  exit(0);
}

sub run {
  my $self = shift;
  my $cmd = $self->{command};

  if ($cmd->can('preprocess')) {
    $cmd->preprocess($self->poll('preprocess'));
  }

  if ($cmd->can('timerEvent')) {
    my $evl = AnyEvent->condvar;

    if ($cmd->can('keyEvent')) {
      ReadMode('cbreak');

      $self->{key-watcher} = AnyEvent->io(fh => \*STDIN
                                        , poll => 'r'
                                        , cb = sub {
                                          my $status = { event => 'keyEvent'
                                                       , now => AnyEvent->now
                                                       };
                                        
                                          $status->{key} = ReadKey(-1);
                                          
                                          if (! $cmd->keyEvent($status)) {
                                            $evl->send;
                                          }
                                        });
    }

    $self->{timer-watcher} = AnyEvent->timer(after => 0
                                           , interval => $self->{config}->{period}
                                           , cb => sub {
                                             my $status = $self->poll('timerEvent'
                                                                    , now => AnyEvent->now
                                                                    );
                                             if (! $cmd->timerEvent($status)) {
                                               $evl->send;
                                             }
                                           });
  
    my $int_watcher = AnyEvent->signal(signal => 'INT', cb => \&_cleanShutdown);
    my $term_watcher = AnyEvent->signal(signal => 'TERM', cb => \&_cleanShutdown);
    my $quit_watcher = AnyEvent->signal(signal => 'QUIT', cb => \&_cleanShutdown);

    $evl->recv;

  }

  if ($cmd->can('postprocess')) {
    $cmd->postprocess($self->poll('postprocess'), $self->{history});
  }
}

sub _initialize_object {
  my ($self, $key) = @_;

  my $package = $self->{config}->{$key}->{package};

  eval {
    use $package;
    $self->{$key} = $self->{config}->{$key}->{package}->new($self->{config}->clone($key));
  };

  if ($@) {
    croak "Failed to load $key package: $@";
  }

  return;
}





