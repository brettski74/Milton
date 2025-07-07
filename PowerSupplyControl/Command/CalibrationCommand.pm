package PowerSupplyControl::Command::CalibrationCommand;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use base qw(PowerSupplyControl::Command::StateMachineCommand);

=head1 METHODS

=head2 eventPrompt($prompt, $validChars)

Prompt the user for a value during event processing using line buffering.

=over

=item $prompt

The prompt to display to the user.

=item $validChars

A reference to a regular expression that only matches valid characters. If not provided, all characters are considered valid.
This does not need to include the backspace or newline characters. Those will always be handled as expected.

=back

=cut

sub eventPrompt {
  my ($self, $nextStage, $status, $prompt, $validChars) = @_;

  croak "\$status parameter is not a hash reference: $status" unless reftype($status) eq 'HASH';
  croak "\$status->{'event-loop'} not defined or is not an EventLoop object: $status->{'event-loop'}" unless ref($status->{'event-loop'}) && $status->{'event-loop'}->isa('PowerSupplyControl::EventLoop');

  $status->{'event-loop'}->startLineBuffering($prompt, $validChars);
  return $self->advanceStage($nextStage, $status);
}

=head2 isLineBuffering($status)

Return true if the command is currently in a line buffer input session, otherwise false.

=over

=item $status

The status object.

=back

=cut

sub isLineBuffering {
  my ($self, $status) = @_;
  return $status->{'event-loop'}->isLineBuffering;
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

=cut

sub newSteadyState {
  my ($self, $status) = @_;

  $self->{'steady-state'} = PowerSupplyControl::Math::SteadyStateDetector($self->{config}->clone('steady-state'));
  $self->{'manual-steady-state'} = 0;
}

=head2 checkSteadyState($value)

Check if the provided parameter value has met the steady state criteria.

=over

=item $value

The current value of the parameter being checked for steady state.

=back

=cut

sub checkSteadyState {
  my ($self, $value) = @_;

  my $manualThreshold = $self->{config}->{'steady-state'}->{'manual-threshold'} || 3;

  return $self->{'steady-state'}->check($value) || $self->{'manual-steady-state'} >= $manualThreshold;
}

=head2 keyEvent($status)

Look for successive presses of the 's' key for the user to manually force steady state detection.

Avoid overriding this method in subclasses. 

=cut

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq 's') {
    $self->{'manual-steady-state'}++;
  } else {
    $self->{'manual-steady-state'} = 0;
  }

  return $self->otherKeys($status);
}

=head2 otherKeys($status)

Additional key event processing that is specific to a subclass of CalibrationCommand.

The default implementation does nothing. This method should be overridden in subclasses to perform any additional
key processing that is specific to the subclass.

=cut

sub otherKeys {
  return shift;
}

=head2 preprocess($status)

Sets up this command object for the calibration to be performed and ensures that
we have an initial measurement of the hotplate state.

Avoid overriding this method in subclasses. Instead, override C<calibrationSetup> to
perform any setup required for the calibration.

=cut

sub preprocess {
  my ($self, $status) = @_;
  my $rc = $self->calibrationSetup($status);

  # Get some current flowing and measure the hotplate state
  $self->{interface}->setCurrent($self->{config}->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll($status);

  return $rc;
}

=head2 calibrationSetup($status)

Set up this command object for the calibration to be performed.

The default implementation does nothing. This method should be overridden in subclasses to perform any setup required
for the calibration prior to the start of the main event loop.

=cut

sub calibrationSetup {
  return shift;
}

sub _dual_print {
  my $fh = shift;

  $fh->print(@_);
  print @_;
}

=head2 writeCalibration($fh, $calibration, %config)

Write out the calibration data to the provided file handle.

=cut

sub writeCalibration {
  my $self = shift;
  my $fh = shift;
  my $calibration = shift;

  while (@_ > 1) {
    my $key = shift;
    my $data = shift;

    _dual_print($fh, "$key: $data\n");
  }

  _dual_print($fh, "\n");

  # Write out RTD calibration
  _dual_print($fh, "temperatures:\n");
  foreach my $point (@$calibration) {
    _dual_print($fh, "  - resistance: $point->{resistance}\n");
    _dual_print($fh, "    temperature: $point->{temperature}\n");
  }

  _dual_print($fh, "\n");

  _dual_print($fh, "thermal-resistance:\n");
  foreach my $point (@$calibration) {
    if ($point->{'thermal-resistance'} > 0) {
      _dual_print($fh, "  - temperature: $point->{temperature}\n");
      _dual_print($fh, "    thermal-resistance: $point->{'thermal-resistance'}\n");
    }
  }

  _dual_print($fh, "\n");

  _dual_print($fh, "heat-capacity:\n");
  foreach my $point (@$calibration) {
    if ($point->{'heat-capacity'} > 0) {
      _dual_print($fh, "  - temperature: $point->{temperature}\n");
      _dual_print($fh, "    heat-capacity: $point->{'heat-capacity'}\n");
    }
  }

  return $self;
}

1;