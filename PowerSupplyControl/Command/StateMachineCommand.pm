package PowerSupplyControl::Command::StateMachineCommand;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Command);

sub new {
    my ($class, $config, $interface, $controller, @args) = @_;

    my $self = $class->SUPER::new($config, $interface, $controller, @args);

    return $self;
}

=head2 timerEvent($status)

Handle a timer event. This method should not be overridden by subclasses. It calls through to the appropriate method based on the current state.

It is important for subclasses to ensure that they have an element named C<stage> and for this value to correspond to the name of a method on
that class if prefixed with an underscore.

=over

=item $status

A hash reference containing the current status of the hotplate.

=back

=cut

sub timerEvent {
  my ($self, $status) = @_;

  $status->{stage} = $self->{stage};
  my $stage = '_'. $self->{stage};

  return $self->$stage($status);
}

=head2 newSteadyState

Prepare this command for detecting a new steady state condition using the command's steady-state criteria.

The following configuration attributes will be used to set the parameters for the steady-state detection:

=over

=item steady-state.samples

The number of successive samples that must meet the steady state criteria for detection.

=item steady-state.threshold

The threshold value for the IIR filter output to start counting steady state samples.

=item steady-state.smoothing

The smoothing factor for the IIR filter.

=item steady-state.reset

The reset threshold above which the steady state sample counter is reset.

=back



=head2 advanceStage($stage, $status)

Advance to the next stage. This method should not be overridden by subclasses. It calls through to the appropriate method based on the current state.

=over

=item $stage

The name of the stage to advance to.

=item $status

A hash reference containing the current status of the hotplate.

=back

=cut

sub advanceStage {
  my ($self, $stage, $status) = @_;

  $self->beep;
  $self->{stage} = $stage;
  $status->{stage} = $stage;
  $stage = "_$stage";

  # Call through to the stage handler, but only if we're in a time event.
  if ($status->{event} eq 'timerEvent') {
    return $self->$stage($status);
  }

  return $self;
}

1;