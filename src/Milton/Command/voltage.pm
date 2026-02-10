package Milton::Command::voltage;

use strict;
use warnings qw(all -uninitialized);

use Time::HiRes qw(sleep);

use base qw(Milton::Command::ManualTuningCommand);
use Carp;
use Milton::Config::Path qw(resolve_writable_config_path);

use Milton::DataLogger qw(get_namespace_debug_level);

use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_DATA => 100;

=head1 NAME

Milton::Command::voltage - Operate the hotplate at a constant voltage level until shut down by the user.

=head1 SYNOPSIS

    use Milton::Command::voltage;

    my $voltage = Milton::Command::voltage->new();

=head1 DESCRIPTION

Operate the hotplate at a constant voltage level until shut down by the user. The command accepts
a single argument - the voltage level in volts. It will then maintain the requested voltage level
until the process is shut down by the user via Ctrl+C, a terminate signal or any other means
by which the process is terminated. Upon shutdown, the command will ensure that the hotplate is
turned off.

=cut

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $self->{voltage} = $self->{args}->[0] || $config->{voltage}->{default};

  croak "Voltage level not specified." unless $self->{voltage};
  croak "Voltage level must be a positive number: $self->{voltage}" unless $self->{voltage} > 0;
  croak "Voltage level is crazy high: $self->{voltage}" unless $self->{voltage} <= $interface->{voltage}->{maximum};

  return $self;
}

sub options {
  return ( 'voltage=i'
         , 'duration=i'
         );
}

sub preprocess {
  my ($self, $status) = @_;

  $self->info("Voltage: $self->{voltage}");
  $self->info("Duration: $self->{duration}") if $self->{duration};

  $self->{interface}->setVoltage($self->{voltage});
  sleep(0.5);
  $self->{interface}->poll($status);

  return $status;
}

sub timerEvent {
  my ($self, $status) = @_;

  # If we've passed the set duration, then power off and exit.
  if ($self->{duration} && $status->{now} > $self->{duration}) {
    $self->{interface}->on(0);
    $self->beep;
    return;
  }

  $self->{interface}->setVoltage($self->{voltage});

  return $status;
}

1;