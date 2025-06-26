package HP::t::MockController;

use strict;
use warnings;

=head1 NAME

HP::t::MockController - Mock Controller for testing

=head1 DESCRIPTION

A mock controller that provides predictable behavior for testing.

=cut

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub getTemperature {
    my ($self, $status) = @_;
    # Add some mock temperature data
    $status->{controller_temp} = 85.2;
    $status->{target_temp} = 100.0;
    return;
}

1; 