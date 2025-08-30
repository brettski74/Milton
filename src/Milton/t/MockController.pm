package Milton::t::MockController;

use strict;
use warnings;
use base qw(Milton::Controller::RTDController);

=head1 NAME

Milton::t::MockController - Mock RTDController for testing

=head1 DESCRIPTION

A mock controller that provides a simple two-point calibration by default.

=cut

sub new {
    my ($class, $config, $interface, @args) = @_;
    my $self = $class->SUPER::new($config, $interface, @args);
    $self->{interface} = $interface // Milton::t::MockInterface->getLastMockInterface;
    $self->setTemperaturePoint(0, 1);
    $self->setTemperaturePoint(100, 2);
    
    $self->{'required-power'} = 23.2;

    return $self;
}
sub setRequiredPower {
  my ($self, $power) = @_;
  my $old = $self->{'required-power'};
  $self->{'required-power'} = $power;
  return $old;
}

sub getRequiredPower {
  my ($self, $status, $target_temperature) = @_;

  return $self->{'required-power'};
}

1; 
