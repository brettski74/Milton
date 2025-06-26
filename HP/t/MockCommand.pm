package HP::t::MockCommand;

use strict;
use warnings;

=head1 NAME

HP::t::MockCommand - Mock Command for testing

=head1 DESCRIPTION

A mock command that provides predictable behavior for testing.

=cut

sub new {
    my ($class, $config, $controller, $interface, @args) = @_;
    return bless {
        config => $config,
        controller => $controller,
        interface => $interface,
        args => \@args
    }, $class;
}

sub timerEvent {
    my ($self, $status) = @_;
    # Return true to continue running
    return 1;
}

sub keyEvent {
    my ($self, $status) = @_;
    # Return true to continue running
    return 1;
}

sub preprocess {
    my ($self, $status) = @_;
    return;
}

sub postprocess {
    my ($self, $status, $history) = @_;
    return;
}

1; 