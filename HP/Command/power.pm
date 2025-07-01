package HP::Command::power;

use strict;
use warnings qw(all -uninitialized);

use Time::HiRes qw(sleep);

use base qw(HP::Command);
use HP::SteadyStateDetector;
use Carp;

=head1 NAME

HP::Command::power - Operate the hotplate at a constant power level until shut down by the user.

=head1 SYNOPSIS

    use HP::Command::power;

    my $power = HP::Command::power->new();

=head1 DESCRIPTION

Operate the hotplate at a constant power level until shut down by the user. The command accepts
a single argument - the power level in watts. It will then maintain the requested power level
until the process is shut down by the user via Ctrl+C, a terminate signal or any other means
by which the process is terminated. Upon shutdown, the command will ensure that the hotplate is
turned off.

=cut

sub new {
    my ($class, $config, $controller, $interface, @args) = @_;

    my $self = $class->SUPER::new($config, $controller, $interface, @args);

    $self->{power} = $args[0] || $config->{power}->{default};

    $self->{samples} //= $config->{'steady-state'}->{samples};
    $self->{threshold} //= $config->{'steady-state'}->{threshold};
    $self->{smoothing} //= $config->{'steady-state'}->{smoothing};
    $self->{reset} //= $config->{'steady-state'}->{reset};

    if ($self->{samples} > 0 && !$self->{run}) {
      $self->{detector} = HP::SteadyStateDetector->new(
        smoothing => $self->{smoothing},
        threshold => $self->{threshold},
        samples => $self->{samples},
        reset => $self->{reset},
      );
    }

    croak "Power level not specified." unless $self->{power};
    croak "Power level must be a positive number: $self->{power}" unless $self->{power} > 0;
    croak "Power level is crazy high: $self->{power}" unless $self->{power} < $interface->{power}->{maximum};

    return $self;
}

sub defaults {
    return { current => { startup => 2 } };
}

=head1 OPTIONS

The following command line options are supported:

=over

=item ambient

The ambient temperature in degrees Celsius.

=item power

The power level in watts. This is equivalent to setting the power via an unqualified numeric argument on the command line, although if both are specified, the unqualified argument takes precedence.

=item samples

The number of samples to use when detecting steady state. If set to 0, steady state detection is disabled.

=item threshold

The threshold for detecting steady state.

=item reset

The reset threshold for detecting steady state.

=item smoothing

The smoothing factor for the steady state detector.

=item run

If set, the command will run continuously until the process is terminated by the user. This is functionally equivalent to setting samples=0.

=back

=cut

sub options {
  return ( 'power=i'
         , 'samples=i'
         , 'threshold=f'
         , 'reset=f'
         , 'smoothing=f'
         , 'run'
         );
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
  } else {
    $self->{'quit-count'} = 0;
  }

  return $status;
}

sub timerEvent {
    my ($self, $status) = @_;

    $self->{controller}->getTemperature($status);


    if ($self->{detector}) {
      $status->{'steady-state-count'} = $self->{detector}->{count};
      $status->{'filtered-delta'} = $self->{detector}->{filtered_delta};

      if ($self->{detector}->check($status->{resistance})) {
        $self->{interface}->off;
        $self->beep;
        return;
      }
    }

    $self->{interface}->setPower($self->{power});

    return $status;
}

1;