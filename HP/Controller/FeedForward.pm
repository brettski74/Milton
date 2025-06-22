package HP::Controller::FeedForward;

use strict;
use Carp qw(croak);
use base qw(HP::Controller::RTDController);

=head1 NAME

HP::Controller::FeedForward - Implements a FeedForward controller that uses a thermal model to predict the power required to reach the next target temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Create a new feed forward controller instance.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Verify mandatory parameters
  croak "resistance not specified." unless $config->{resistance};
  croak "capacity not specified." unless $config->{capacity};

  # Set defaults if required
  $self->{ambient} = $config->{ambient} || 20.0;

  return $self;
}

sub setTemperature {
  my ($self, $status, $futureTemperature) = @_;

}

1;
