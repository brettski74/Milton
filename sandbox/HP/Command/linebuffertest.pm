package HP::Command::linebuffertest;

use strict;
use warnings qw(all -uninitialized);

use base qw(HP::Command);

sub keyEvent {
  my ($self, $status)= @_;

  if ($status->{key} eq 'p') {
    $self->eventPrompt($status, 'Enter something: ', qr/[0-9a-z.]/);
  }

  return $status;
}

sub lineEvent {
  my ($self, $status) = @_;

  return if ($status->{line} eq 'exit');

  print "lineEvent: $status->{line}\n";
  return $status;
}

sub timerEvent {
  my ($self, $status) = @_;

  $status->{resistance} = $status->{voltage} / $status->{current};

  return $status;
}

1;
