package HP::t::MockInterface;

use strict;
use warnings;
use base qw(HP::Interface);

=head1 NAME

HP::t::MockInterface - Mock Interface for testing

=head1 DESCRIPTION

A mock interface that returns predictable data for testing.

=cut

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new({});
    $self->{poll_count} = 0;
    return $self;
}

sub poll {
    my ($self) = @_;
    $self->{poll_count}++;
    return {
        id => $self->{poll_count},
        voltage => 12.5,
        current => 2.1,
        power => 26.25,
        temperature => 85.2
    };
}

sub setVoltage { return; }
sub setCurrent { return; }
sub setPower { return; }
sub shutdown { return; }

1; 