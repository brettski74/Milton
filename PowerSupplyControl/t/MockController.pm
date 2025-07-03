package PowerSupplyControl::t::MockController;

use strict;
use warnings;
use base qw(PowerSupplyControl::Controller::RTDController);

=head1 NAME

PowerSupplyControl::t::MockController - Mock RTDController for testing

=head1 DESCRIPTION

A mock controller that provides a simple two-point calibration by default.

=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->setTemperaturePoint(0, 1);
    $self->setTemperaturePoint(100, 2);
    return $self;
}

1; 