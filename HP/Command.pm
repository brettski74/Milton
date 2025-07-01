package HP::Command;

use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case bundling require_order);
use Hash::Merge;

=head1 NAME

HP::Command - Base class for all commands

=head1 SYNOPSIS

  my $self = HP::Command->new($config);

  return $self;
}

=head1 DESCRIPTION

This is the base class for all commands. To be loadable as commands, subclasses of HP::Command should be placed in
the HP::Command::* namespace and begin with a lowercase letter. Subclasses beginning with an uppercase letter should
be used for base classes that implement common logic but do not implement a complete command.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new command object with the specified properties.

Subclasses should ensure that they call the superclass constructor so that the base class is properly initialized.
Most often, it should be sufficient to leave this unimplemented and implement the initialize method instead.

=cut

sub new {
  my ($class, $config, $controller, $interface, @args) = @_;

  my $self = { controller => $controller
             , interface => $interface
             , args => \@args
             };

  bless $self, $class;

  my $merge = Hash::Merge->new('LEFT_PRECEDENT');
  $self->{config} = $merge->merge($config, $self->defaults);

  my @options = $self->options;
  push @options, 'ambient=f';

  GetOptionsFromArray(\@args, $self, @options);

  if (defined $self->{ambient}) {
    $self->{controller}->setAmbient($self->{ambient});
  }

  $self->initialize() if $self->can('initialize');

  return $self;
}

sub timestamp {
  my ($sec, $min, $hour, $day, $month, $year) = localtime(time);
  return sprintf("%04d%02d%02d-%02d%02d%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);
}

=head1 STATUS OBJECT

The status object is a hash reference that contains the current state of the system. It is passed to all methods processing
methods for the command. The following keys are always present in the status object unless specified otherwise:

=over

=item now

The current time in seconds since the start of the command.

=item voltage

The current voltage applied to the hotplate in volts. This is not present during keyEvents.

=item current

The current current drawn by the hotplate in amps. This is not present during keyEvents.

=item power

The current power output of the hotplate in watts. This is not present during keyEvents.

=item temperature

The current temperature of the hotplate in degrees Celsius. This is not present during keyEvents.

=back

=cut


=head1 METHODS

=head2 defaults

Return a hash of default configuration values for this command.

The default implementation returns an empty hash. Classes that require defaulting behaviour should override this method.

=cut

sub defaults {
  return {};
}

=head2 options

Return a list of options for Getopt::Long parsing of the command line arguments.

The default implementation returns an empty list. Classes that require options should override this method.

=cut

sub options {
  return;
} 

=head2 initialize

Initialize the command.

Implement this method in subclasses for commands that require any specific initialization logic during their creation.

=cut

# Don't implement here. The framework will use ->can to determine if the command implements this method.
#sub initialize {
#  return;
#}

=head2 preprocess($status)

Implement this method in subclasses for commands that require any specific pre-processing logic prior to the main event loop operation.

This method should be used for any non-timer related pre-processing. Unlike the initialize method, which is called during object
creation, this method is called after all necessary initialization of the command and other object and system state is complete.

=cut

# Don't implement here. The framework will use ->can to determine if the command implements this method.
#sub preprocess {
#  return;
#}

=head2 timerEvent($status)

Implement this method in subclasses for commands that require any specific timer event logic.

This method is called every time the timer event is triggered. Timer events should be careful to avoid blocking or
long running operations. Depending on the configuration, most of the time between timer events may be spent polling
and updating the hotplate status.

=cut

# Don't implement here. The framework will use ->can to determine if the command implements this method.
#sub timerEvent {
#  return;
#}

=head2 keyEvent($status)

Implement this method in subclasses for commands that require any specific key event logic.

keyPress events are normally highly time-sensitive. Minimal logic should be implemented here such as updating
internal state to reflect the key press. This method should definitely avoid blocking or slow operations like
polling the hotplate status. If hotplate status is required, the keyPress event should update internal state
to reflect what key was pressed and when and then use interpolation either in the next timerEvent or in the
postprocess method.

This method is called every time a key is pressed, but only during the event loop and the event loop won't be
executed unless this command also implements the timerEvent method. The following additional keys are present
in the status object for keyEvents:

=over

=item key

The key that was pressed.

=back

=cut

# Don't implement here. The framework will use ->can to determine if the command implements this method.
#sub keyEvent {
#  return;
#}

=head2 lineEvent($status)

Implement this method in subclasses for commands that require any specific line event logic. Will not work
without also defining the keyEvent method. The $status object will contain the following additional keys:

=over

=item line

The line of input from the user.

=back

=cut

sub lineEvent {  
  return;
}

=head2 postprocess($status, $history)

Implement this method in subclasses for commands that require any specific post-processing logic after the main event loop operation.

=over

=item status

The status object representing the final state of the system after the main event loop operation.

=item history

A reference to an array containing all of the status objects generated from preprocess until the end, in order. This includes the
status object passed to the postprocess method.

=back

=cut

# Don't implement here. The framework will use ->can to determine if the command implements this method.
#sub postprocess {
#  return;
#}

=head2 prompt($prompt, default, @keys)

Prompt the user for a value.

=over

=item $prompt

The text prompt to display to the user.

=item $default

The default value to use if the user presses enter without typing anything.

=item Return Value

The value entered by the user, or the default value if nothing was entered. If the user presses enter without typing anything,
the default value will be returned.

=back

=cut

sub prompt {
  my ($self, $prompt, $default) = @_;

  print "$prompt [$default] ";
  my $value = <STDIN>;
  chomp $value;
  $value =~ s/^\s+//;
  $value =~ s/\s+$//;

  if ($value eq '') {
    return $default;
  }

  return $value;
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
  my ($self, $status, $prompt, $validChars) = @_;

  $status->{'event-loop'}->startLineBuffering($prompt, $validChars);
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

=head2 beep

Beep the terminal.

=cut

sub beep {
  print "\a";
}

=head1 AUTHOR

=cut

1;
