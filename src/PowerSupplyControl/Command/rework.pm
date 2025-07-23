package PowerSupplyControl::Command::rework;

use strict;
use warnings qw(all -uninitialized);

use Time::HiRes qw(sleep);

use base qw(PowerSupplyControl::Command);
use Carp;

=head1 NAME

PowerSupplyControl::Command::power - Operate the hotplate at a constant power level until shut down by the user.

=head1 SYNOPSIS

    use PowerSupplyControl::Command::power;

    my $power = PowerSupplyControl::Command::power->new();

=head1 DESCRIPTION

Operate the hotplate at a constant power level until shut down by the user. The command accepts
a single argument - the power level in watts. It will then maintain the requested power level
until the process is shut down by the user via Ctrl+C, a terminate signal or any other means
by which the process is terminated. Upon shutdown, the command will ensure that the hotplate is
turned off.

=cut

sub new {
    my ($class, $config, $interface, $controller, @args) = @_;

    my $self = $class->SUPER::new($config, $interface, $controller, @args);

    $self->{'rework-temperature'} = $self->{args}->[0] || $config->{'rework-temperature'};

    croak "Temperature not specified." unless $self->{'rework-temperature'};
    croak "Temperature must be a positive number: $self->{'rework-temperature'}" unless $self->{'rework-temperature'} > 0;
    croak "Temperature is crazy high: $self->{'rework-temperature'}" unless $self->{'rework-temperature'} < 230;

    return $self;
}

sub defaults {
    return { current => { startup => 2 } };
}

=head1 OPTIONS

The following command line options are supported:

=over

=item duration

The time to run for in seconds. It set, the command will shut off power and exit after running for the specified duration.

=back

=cut

sub options {
  return ( 'duration=i' );
}

sub preprocess {
  my ($self, $status) = @_;

  # Ensure that we have some current through the hotplate so we will be able to measure resistance and set output power.
  $self->{interface}->setCurrent($self->{config}->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll;

  return $status;
}

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq 'q') {
    $self->{'quit-count'}++;

    if ($self->{'quit-count'} > 3) {
      $self->{interface}->shutdown;
      return;
    }
  } elsif ($status->{key} eq 'up') {
    $self->{'rework-temperature'} += 1;
  } elsif ($status->{key} eq 'down') {
    $self->{'rework-temperature'} -= 1;
  } else {
    $self->{'quit-count'} = 0;
  }

  return $status;
}

sub timerEvent {
    my ($self, $status) = @_;

    $self->{controller}->getTemperature($status);

    # If we've passed the set duration, then power off and exit.
    if ($self->{duration} && $status->{now} > $self->{duration}) {
      $self->{interface}->on(0);
      $self->beep;
      return;
    }

    $status->{'then-temperature'} = $status->{'now-temperature'} = $self->{'rework-temperature'};

    my $power = $self->{controller}->getRequiredPower($status);
    $status->{'set-power'} = $power;
    $self->{interface}->setPower($power);

    return $status;
}

1;