package HP::t::MockController;

use strict;
use warnings;
use base qw(HP::Controller::RTDController);

=head1 NAME

HP::t::MockController - Mock RTDController for testing

=head1 DESCRIPTION

A mock controller that provides a simple two-point calibration by default.

=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->setCalibrationPoint(0, 1);
    $self->setCalibrationPoint(100, 2);
    return $self;
}

1; 