package Milton::Command::power;

use strict;
use warnings qw(all -uninitialized);

use Time::HiRes qw(sleep);

use base qw(Milton::Command);
use Milton::Math::SteadyStateDetector;
use Carp;

=head1 NAME

Milton::Command::power - Operate the hotplate at a constant power level until shut down by the user.

=head1 SYNOPSIS

    use Milton::Command::power;

    my $power = Milton::Command::power->new();

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

    $self->{power} = $self->{args}->[0] || $config->{power}->{default};

    croak "Power level not specified." unless $self->{power};
    croak "Power level must be a positive number: $self->{power}" unless $self->{power} > 0;
    croak "Power level is crazy high: $self->{power}" unless $self->{power} <= $interface->{power}->{maximum};

    return $self;
}

=head1 OPTIONS

The following command line options are supported:

=over

=item power

The power level in watts. This is equivalent to setting the power via an unqualified numeric argument on the command line, although if both are specified, the unqualified argument takes precedence.

=item run

If set, the command will run continuously until the process is terminated by the user. This is functionally equivalent to setting samples=0.

=item duration

The time to run for in seconds. It set, the command will shut off power and exit after running for the specified duration.

=back

=cut

sub options {
  return ( 'power=i'
         , 'duration=i'
         , 'run'
         );
}

sub preprocess {
  my ($self, $status) = @_;

  $self->info("Power: $self->{power}");
  $self->info("Duration: $self->{duration}") if $self->{duration};

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
    $self->{power} += 1;
  } elsif ($status->{key} eq 'down') {
    $self->{power} -= 1;
  } else {
    $self->{'quit-count'} = 0;
  }

  return $status;
}

sub timerEvent {
    my ($self, $status) = @_;

    $self->{controller}->getTemperature($status);

    # We don't need it for control, but getting the predicted temperature is useful for web UI display and data logging.
    my $predictor = $self->{controller}->getPredictor;
    if ($predictor) {
      $predictor->predictTemperature($status);
    }
    $status->{'set-power'} = $self->{power};

    # If we've passed the set duration, then power off and exit.
    if ($self->{duration} && $status->{now} > $self->{duration}) {
      $self->{interface}->on(0);
      $self->beep;
      return;
    }

    if ($self->{detector}) {
      $status->{'steady-state-count'} = $self->{detector}->{count};
      $status->{'filtered-delta'} = $self->{detector}->{'filtered-delta'};

      if ($self->{detector}->check($status->{resistance})) {
        $self->{interface}->off;
        $self->beep;
        return;
      }
    }

    my $power = $self->{controller}->getPowerLimited($status);

    $self->{interface}->setPower($power);

    return $status;
}

1;