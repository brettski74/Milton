package PowerSupplyControl::Command::CalibrationCommand;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use base qw(PowerSupplyControl::Command::StateMachineCommand);
use List::Util qw(min);

=head1 CONSTRUCTOR

=head2 new($config, $interface, $controller, @args)

Create a new CalibrationCommand object. This calls through to the superclass constructor, but
also sets up the ambient temperature if it is not already set from the command line.

=cut

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $self->infoMessage();

  if (!defined $self->{ambient}) {
    if ($self->{controller}->hasTemperatureDevice) {
      my ($hot, $cold) = $self->{controller}->getDeviceTemperature;
      if (defined $cold) {
        $self->{ambient} = min($hot, $cold);
      } else {
        $self->{ambient} = $hot;
      }

      print "Set ambient temperature to $self->{ambient}\n";
    } else {
      $self->{ambient} = $self->prompt('Ambient temperature', $config->{'ambient-temperature'} || 25);
    }
  }

  bless $self->{config}, 'PowerSupplyControl::Config';

  return $self;
}

=head1 METHODS

=head2 infoMessage

Display an information message to the user. This will typically include details such as ensuring
that the hotplate is currently resting at ambient temperature, that any unnecessary fans or
ventilation systems are turned off and that the calibration may take some time and require user
attention.

=cut

sub infoMessage {
  print <<'EOS';
You are about to begin a calibration cycle for your hotplate. A typical calibration cycle may take
30 to 60 minutes to complete assuming about a 6 point calibration. It may require your input at
times. Ensure that you are comfortable and have sufficient time to complete the calibration. The
calibration should beep when it passes various stages or requires user input.

The temperature of the hotplate can be very sensitive to the flow of air around it. Ensure that
any unnecessary fans or ventilation systems are turned off. You can continue working around the
fan but be aware that rapid movements near the hotplate may cause air currents that could affect
the results of the calibration.

The hotplate should be resting at ambient temperature. If it has recently been used, it may still
be at a higher temperature than ambient. If that is the case, allow the hotplate to cool down to
ambient temperature before beginning. You can use fans to cool the hotplate down faster. Just ensure
to turn them off before beginning the calibration.

Your reference sensor (eg. thermocouple, digital thermometer, etc) should be securely attached to
the centre of the hotplate now. The calibration will require a measurement of the ambient
temperature for reference. You can use the reference sensor attached to your hotplate but it is
strongly recommended to confirm that with a measurement taken from elsewhere to ensure that your
hotplate is currently at ambient temperature.

Finally, note that a side effect of the event framework used to run these commands can make the
keyboard response a little sluggish at times. If your keypresses don't seem to be registering,
hit some more keys and/or use backspace to correct any errors in your entry. If you are confident
that your response is correct and complete, try hitting ENTER again.

EOS
}

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

  my $config = $self->{config}->clone('steady-state');
  $self->{'steady-state'} = PowerSupplyControl::Math::SteadyStateDetector->new(%$config);
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

=head2 _fanCoolDown($status)

A default stage taht can be advanced to to use fan cooling of the hotplate at the end of a
calibration run.

=cut

sub _fanCoolDown {
  my ($self, $status) = @_;

  return $status->{'event-loop'}->fanStart($status, $self->{ambient});
}

1;