package Milton::WebDataLogger;

use base 'Milton::DataLogger';

sub consoleProcess {
  my ($self, $type, $output) = @_;

  $| = 1;
  chomp $output;

  $output =~ s/\r?\n/\n$type: /g;

  return "$type: $output\n";
}

sub consoleGroupProcess {
  my ($self, $type, $output) = @_;

  $| = 1;
  chomp $output;

  my @lines = split /\n/, $output;
  my $line_count = scalar @lines;
  for (my $i = 0; $i < $line_count; $i++) {
    my $remaining = $line_count - $i - 1;
    $lines[$i] =~ s/^\s+//;
    $lines[$i] =~ s/\s+$//;
    print "$type:$remaining: $lines[$i]\n";
  }
}

=head2 prompt($message, $default)

Prompt the user for a value via the web interface.

Outputs the prompt with PROMPT: prefix to stdout, with line numbers
indicating remaining lines. For multi-line prompts, each line is
prefixed with PROMPT:N: where N is the number of remaining lines
(0 for the last line).

=over

=item $message

The prompt message to display to the user. Can be a multi-line string.

=item $default

The default value to return if the user enters a blank response.

=item Return Value

The value entered by the user, or the default value if nothing was entered.

=back

=cut

sub prompt {
  my $self = shift;
  my $message = shift;
  my $attr;

  if (@_ > 1) {
    $attr = { @_ };
  } else {
    $attr = { default => shift };
  }

  if ($attr->{error}) {
    $self->consoleGroupProcess('PROMPT-ERROR', $attr->{error});
  }

  $self->consoleGroupProcess('PROMPT', $message);

  # Read response from STDIN
  my $value = <STDIN>;
  if (defined $value) {
    chomp $value;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    
    if ($value eq '') {
      return $attr->{default};
    }
    
    return $value;
  }
  
  # If STDIN read failed, return default
  return $attr->{default};
}

1;