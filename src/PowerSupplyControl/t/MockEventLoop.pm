package PowerSupplyControl::t::MockEventLoop;

use strict;
use warnings;
use base qw(PowerSupplyControl::EventLoop);
use PowerSupplyControl::t::MockInterface;
use PowerSupplyControl::t::MockController;
use PowerSupplyControl::t::MockCommand;
use PowerSupplyControl::Config;

=head1 NAME

PowerSupplyControl::t::MockEventLoop - Mock EventLoop for testing

=head1 DESCRIPTION

A mock version of PowerSupplyControl::EventLoop that allows injection of mock objects
for testing purposes.

=cut

sub new {
    my ($class, $config, $command, @args) = @_;
    
    # Create a minimal config if none provided
    $config ||= {
        period => 1,
        interface => { package => 'PowerSupplyControl::t::MockInterface' },
        controller => { package => 'PowerSupplyControl::t::MockController' },
        command => { package => 'PowerSupplyControl::t::MockCommand' },
        logging => { enabled => 0 }
    };
    bless $config, 'PowerSupplyControl::Config';
    
    my $self = $class->SUPER::new($config, $command, @args);

    $self->{now} = 0;
    $self->{time} = 0;
    
    return $self;
}

sub _now {
  my ($self) = @_;

  return $self->{now}++;
}

sub _time {
  my ($self) = @_;

  return $self->{time}++;
}

sub _initializeObject {
    my ($self, $key) = @_;
    
    # Use mock objects for testing
    if ($key eq 'interface') {
        $self->{interface} = PowerSupplyControl::t::MockInterface->new;
    } elsif ($key eq 'controller') {
        $self->{controller} = PowerSupplyControl::t::MockController->new({}, $self->{interface});
    }
    
    return;
}

sub _initializeCommand {
    my ($self, $command, @args) = @_;
    $self->{command} = PowerSupplyControl::t::MockCommand->new;
}

1; 