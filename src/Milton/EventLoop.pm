package Milton::EventLoop;

use strict;
use AnyEvent;
use EV;
use Carp qw(cluck croak);
use Term::ReadKey;
use Milton::DataLogger;
use Readonly;
use Milton::ValueTools qw(boolify);

=head1 NAME

Milton::EventLoop - Main event loop environment for the hotplate controller.

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
             , fan => {}
             , history => []
             };

  bless $self, $class;

  my $loggerPackage = 'Milton::DataLogger';
  if (exists $self->{config}->{logger}->{package}) {
    $loggerPackage = $self->{config}->{logger}->{package};
  }

  eval "use $loggerPackage";

  $self->{logger} = $self->_initializeNamedObject($loggerPackage, $self->{config}->clone('logging'), command => $command);

  # Ensure that the fan, if any, is stopped.
  $self->fanStop(1);
  # Give the fan time to stop, just in case it's running.
  sleep(2);

  $self->_initializeObject('interface');
  $self->_initializeObject('controller', $self->{interface});

  $self->_initializeCommand($command, @args);

  $self->{command}->setLogger($self->{logger});
  $self->{interface}->setLogger($self->{logger});
  $self->{controller}->setLogger($self->{logger});

  $self->{console} = 1;

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

  my $update_delay = $self->{interface}->getLastUpdateDelay;

  my $status = $self->{interface}->poll();
  if (defined $update_delay) {
    $status->{'last-update-delay'} = $update_delay;
    $status->{'average-update-delay'} = $self->{interface}->getUpdateDelay;
  }

  $status->{event} = $event;
  $status->{period} = $self->{config}->{period};

  while (@attrs) {
    my $key = shift @attrs;
    my $val = shift @attrs;
    if (!exists $status->{$key}) {
      $status->{$key} = $val;
    }
  }

  $status->{ambient} = $self->{ambient} if defined $self->{ambient};
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

  # Make sure that we always pass the event loop object to the command
  $status->{'event-loop'} = $self;

  push(@{$self->{history}}, $status);

  return $status;
}

=head2 setAmbient($temperature)

Set the current ambient temperature. If supplied, this will be be populated in status
objects passed to event handlers.

=over

=item $temperature

The current ambient temperature in degrees Celsius. If undefined, the current ambient
temperature will be cleared.

=item Return Value

Returns the previous value that was set, or undef if no previous value was set.

=back

=cut

sub setAmbient {
  my ($self, $temperature) = @_;
  if (defined $temperature) {
    my $old = $self->{ambient};
    $self->{ambient} = $temperature;
    return $old;
  }

  delete $self->{ambient};
  return;
}

=head2 fanConnect

Connect to the fan interface.

=cut

sub fanConnect {
  my ($self) = @_;
  my $fan = $self->{fan};
  my $config = $self->{config};
  my $fanConfig = $config->{fan};

  if (exists $fan->{interface}) {
    return $fan->{interface};
  }

  boolify($fanConfig->{enabled});
  if (!$fanConfig->{enabled}) {
    $self->{logger}->info("Fan disabled, No fan cooling for you!") if !exists $fan->{'disable-logged'};
    $fan->{'disable-logged'} = 1;
    return;
  }

  eval {
     my $ifConfig = $config->clone('fan', 'interface');

     $fan->{interface} = $self->_initializeNamedObject($ifConfig->{package}, $ifConfig);
   };

   if ($@) {
     $self->{logger}->warning('Failed to initialize fan interface: %s', $@);
     $fanConfig->{enabled} = 0;
   }
   if (!defined $fan->{interface}) {
     $self->{logger}->warning("No fan interface, so no fan cooling");
     $fanConfig->{enabled} = 0;
     return;
   }

   if (defined($fanConfig->{'shutdown-on-signal'})) {
     boolify($fanConfig->{'shutdown-on-signal'});
     if (!$fanConfig->{'shutdown-on-signal'}) {
       $fan->{interface}->noOffOnShutdown(1);
     }
   }

  return $fan->{interface};
}

=head2 fanStart

If configured, cool down the hot plate by turning on a fan.

The fan can be configured using another Interface object with connection parameters
to a second power supply connected to the fan. This can be useful for cooling the 
hotplace and/or load more quickly after the completion of a command. Commands may
call this at the end of their normal processing if required. This will turn on the
fan and return a hash containing the fan configuration.

=over

=item $status

The status hash containing the current state of the hotplate.

=item $ambient

The current ambient temperature.

=item Return Value

Returns true if the fan is configured and the fan cooldown criteria are met, otherwise returns false.

=back

=cut

sub fanStart {
  my ($self, $status, $ambient) = @_;
  my $config = $self->{config};

  my $fanConfig = $config->{fan};
  my $fan = $self->{fan};

  if (! $fan->{started}) {
    $fan->{started} = $status->{now};
    $ambient //= $status->{ambient};
    $fan->{ambient} = $ambient;

    my $interface = $self->fanConnect;
    return if !$interface;

    if ($fanConfig->{'finish-temperature'}) {
      # If specified in terms of ambient, then adjust accordingly
      if ($fanConfig->{'finish-temperature'} =~ /ambient(\s*\+\s*(\d+(\.\d+)))?/) {
        $fan->{'finish-temperature'} = $ambient + $2;
      } else {
        $fan->{'finish-temperature'} = $fanConfig->{'finish-temperature'};
      }

      if ($status->{temperature} <= $fan->{'finish-temperature'}) {
        $self->{logger}->info("Temperature below finish temperature, no fan cooling required.");
        return;
      }
    }

    # Must have a fan duration so we don't sit waiting forever!
    if ($fanConfig->{'duration'} <= 0) {
      $self->{logger}->info("No fan duration, no fan cooling for you!");
      return;
    }
    $fan->{'finish-time'} = $fan->{started} + $fanConfig->{'duration'};

    # Turn on the fan!
    $self->{logger}->info("Starting fan");
    $interface->setVoltage($fanConfig->{voltage}, $fanConfig->{current} || 10);
    return 1;
  }

  return !$self->fanComplete($status);
}

=head2 fanComplete

Check if the fan cooldown is complete.

Fan cooldown is complete if any of the following conditions are met:

  1. The fan has been running for the configured duration in seconds.
  2. The hotplate is at or below the configured finish temperature.
  3. The hotplate is at or below the ambient temperature.

=over

=item Return Value

Returns false if the fan is configured, fan cooldown has been started and is not yet complete.
Otherwise, it returns true.

=back

=cut

sub fanComplete {
  my ($self, $status) = @_; 

  my $fan = $self->{fan};

  if (! $fan->{started}) {
    return 1;
  }

  my $stop = 0;

  # Have we reached the finish time?
  if ($fan->{'finish-time'} <= $status->{now}) {
    $stop = 1;
  }

  # Have we reached the finish temperature?
  if (exists($fan->{'finish-temperature'}) && $status->{temperature} <= $fan->{'finish-temperature'}) {
    $stop = 1;
  }

  # Have we reached the ambient temperature?
  if ($status->{temperature} <= $fan->{ambient}) {
    $stop = 1;
  }

  if ($stop) {
    $self->fanStop;
  }

  return $stop;
}

sub fanStop {
  my ($self, $force) = @_;
  my $fan = $self->{fan};

  return if !$force && ! $fan->{started};

  my $interface = $self->fanConnect;
  if ($interface) {
    $self->{logger}->info("Stopping fan");
    $interface->on(0);
  }

  delete $fan->{started};
}

sub isLineBuffering {
  my ($self) = @_;
  return exists $self->{'line-buffer'};
}

sub startLineBuffering {
  my ($self, $prompt, $validChars) = @_;

  croak "Line buffering is not supported when console is disabled" if !$self->hasConsole;

  $self->{'line-buffer'} = '';
  $self->{'line-buffer-valid-chars'} = $validChars;
  $| = 1;
  $self->{logger}->hold;
  print $prompt;

  return;
}
Readonly my $BACKSPACE => "\b";
Readonly my $DELETE => "\x7f";

sub lineBufferInput {
  my ($self, $status) = @_;

  croak "Line buffering is not supported when console is disabled" if !$self->hasConsole;

  my $char = $status->{key};

  if ($char eq $BACKSPACE || $char eq $DELETE) {
    if ($self->{'line-buffer'} ne '') {
      print "\b \b";
    }
    $self->{'line-buffer'} = substr $self->{'line-buffer'}, 0, -1;
  } elsif ($char eq "\n" || $char eq "\r") {
    print "\n";
    $| = 0;
    my $result = delete $self->{'line-buffer'};
    delete $self->{'line-buffer-valid-chars'};
    $self->{logger}->release;
    return $result;
  } elsif (!$self->{'line-buffer-valid-chars'} || $char =~ /$self->{'line-buffer-valid-chars'}/) {
    print $char;
    $self->{'line-buffer'} .= $char;
  }
  return;
}

sub _now {
  my ($self) = @_;
  my $now = AnyEvent->now;
#  if (!exists $self->{'start-time'}) {
#    $self->{'start-time'} = $now;
#  }
  return $now - $self->{'start-time'};
}

sub _time {
  my ($self) = @_;

  return AnyEvent->time - $self->{'start-time'};
}

=head2 run

Run the event loop.

=cut

sub _signalWatcher {
  my ($self, $signal) = @_;

  if ($self->{command}->can('quitEvent')) {
    my $status = { now => $self->_now 
                 , time => $self->_time
                 , event => 'quitEvent'
                 , signal => $signal
                 , 'event-loop' => $self
                 };
    push @{$self->{history}}, $status;
    my $continue = $self->{command}->quitEvent($status);
    $self->{logger}->log($status);
    
    return if $continue;
  }

  $self->_eventsDone;

  $self->{interface}->shutdown;
  $self->{controller}->shutdown;

  if ($self->{fan}) {
    my $shutdown_on_signal = $self->{config}->{fan}->{'shutdown-on-signal'};
    if (!defined($shutdown_on_signal) || $shutdown_on_signal) {
      $self->fanStop;
    } else {
      $self->{logger}->info("Fan shutdown on signal disabled");
    }
  }

  # Trash our objects so they get destroyed.
  $self->{interface} = undef;
  $self->{controller} = undef;
  $self->{command} = undef;
  $self->{fan} = undef;

  exit(0);
}

sub _eventsDone {
  my ($self) = @_;

  ReadMode('normal');

  $self->{interface}->on(0);

  return;
}

END {
  ReadMode('normal');
}

Readonly my %KEY_MAP => ( "\e[A"   => 'up'
                        , "\e[B"   => 'down'
                        , "\e[C"   => 'right'
                        , "\e[D"   => 'left'
                        , "\e[F"   => 'end'
                        , "\e[H"   => 'home'
                        , "\e[2~"  => 'insert'
                        , "\e[3~"  => 'delete'
                        , "\e[5~"  => 'pageup'
                        , "\e[6~"  => 'pagedown'
                        , "\e[7~"  => 'home'
                        , "\e[8~"  => 'end'
                        , "\e[9~"  => 'delete'
                        , "\e[11~" => 'f1'
                        , "\e[12~" => 'f2'
                        , "\eOP"   => 'f1'
                        , "\eOQ"   => 'f2'
                        , "\eOR"   => 'f3'
                        , "\eOS"   => 'f4'
                        , "\e[15~" => 'f5'
                        , "\e[17~" => 'f6'
                        , "\e[18~" => 'f7'
                        , "\e[19~" => 'f8'
                        , "\e[20~" => 'f9'
                        , "\e[21~" => 'f10'
                        , "\e[23~" => 'f11'
                        , "\e[24~" => 'f12'
                        );
sub _readKey {
  my ($self) = @_;
  my $key = ReadKey(-1);
  if (defined $key) {
    if ($key eq "\e") {
      # Escape sequence
      while (defined(my $next = ReadKey(-1))) {
        $key .= $next;
      }

      if (exists $KEY_MAP{$key}) {
        return $KEY_MAP{$key};
      }
    }
    return $key;
  }
  return;
}

sub _keyWatcher {
  my ($self, $evl) = @_;

  my $cmd = $self->{command};

  my $status = { event => 'keyEvent'
               , 'event-loop' => $self
               , now => $self->_now
               , time => $self->_time
               , key => $self->_readKey
               , ambient => $self->{ambient}
               };

  if ($self->{'last-timer-status'}) {
    $status->{last} = $self->{'last-timer-status'};
  }

  push(@{$self->{history}}, $status);

  if ($self->isLineBuffering) {
    $status->{line} = $self->lineBufferInput($status);
    if (defined $status->{line}) {
      $status->{event} = 'lineEvent';
      delete $status->{key};
      if (! $cmd->lineEvent($status)) {
        $self->{logger}->log($status);
        $evl->send;
        return;
      }
    }
  } else {
    if (! $cmd->keyEvent($status)) {
      $self->{logger}->log($status);
      $evl->send;
      return;
    }
    $self->{logger}->log($status);
  }
                                          
}

sub _timerWatcher {
  my ($self, $evl) = @_;

  my $cmd = $self->{command};
  my $status;
  my $rc;

  eval {
    $status = $self->poll('timerEvent'
                        , now => $self->_now
                        , ambient => $self->{ambient}
                        );

    $rc = $cmd->timerEvent($status);
  };
  if ($@) {
    $self->{logger}->error("Error in timerEvent: $@");
    $evl->send;
    return;
  }
  $self->{logger}->log($status);
  if (! $rc) {
    $evl->send;
  }
}

sub run {
  my $self = shift;
  my $cmd = $self->{command};
  my $logger = $self->{logger};

  if ($cmd->can('preprocess')) {
    my $status = $self->poll('preprocess');
    $cmd->preprocess($status);

    if (!defined $self->{ambient}) {
      if (defined $status->{ambient}) {
        $self->setAmbient($status->{ambient});
      } elsif (defined $status->{temperature}) {
        $self->setAmbient($self->{controller}->getAmbient($status));
      }
    }

    $logger->writeHeader;
    $logger->log($status);
  } else {
    $logger->writeHeader;
  }

  if ($cmd->can('timerEvent')) {
    my $evl = AnyEvent->condvar;
    # Make sure we reset AnyEvent's internal clock to avoid catch-up issues at startup
    AnyEvent->now_update;
    $self->{'start-time'} = AnyEvent->time;

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

    $self->{controller}->startDeviceListening;

    my $int_watcher = AnyEvent->signal(signal => 'INT', cb => sub { $self->_signalWatcher('INT') });
    my $term_watcher = AnyEvent->signal(signal => 'TERM', cb => sub { $self->_signalWatcher('TERM') });
    my $quit_watcher = AnyEvent->signal(signal => 'QUIT', cb => sub { $self->_signalWatcher('QUIT') });

    $evl->recv;

    $self->_eventsDone;
  }

  if ($cmd->can('postprocess')) {
    my $status = $self->poll('postprocess');
    $cmd->postprocess($status, $self->{history});
    $logger->log($status);
  }

  $self->{interface}->shutdown;
  $self->{controller}->shutdown;
  $self->fanStop;
}

=head2 getHistory

Get the complete history of hotplate status.

=cut

sub getHistory {
  my ($self) = @_;

  return $self->{history};
}

sub _initializeObject {
  my ($self, $key, @args) = @_;

  my $package = $self->{config}->{$key}->{package};

  my $config = $self->{config}->clone($key);
  $config->{logger} = $self->{logger};

  eval {
    $self->{$key} = $self->_initializeNamedObject($package, $config, @args);
  };

  if ($@) {
    if ($@ =~ /Failed to load package/) {
      croak "Failed to load $key package ($package): $@";
    }

    croak "Failed to initialize $key: $@";
  }

  return;
}

sub _initializeNamedObject {
  my ($self, $package, @args) = @_;

  eval "use $package";

  if ($@) {
    croak "Failed to load package $package: $@";
  }

  return $package->new(@args);
}

sub _initializeCommand {
  my ($self, $command, @args) = @_;

  my $cmd_pkg = "Milton::Command::$command";

  $self->{command} = $self->_initializeNamedObject($cmd_pkg
                                                 , $self->{config}->clone('command', $command)
                                                 , $self->{interface}
                                                 , $self->{controller}
                                                 , @args
                                                 );
}

sub hasConsole {
  my $self = shift;
  my $rc = $self->{console};

  if (@_) {
    $self->{console} = shift;
  }

  return $rc;
}

sub getController {
  my ($self) = @_;
  return $self->{controller};
}

sub getInterface {
  my ($self) = @_;
  return $self->{interface};
}

1;
