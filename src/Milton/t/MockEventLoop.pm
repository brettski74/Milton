package Milton::t::MockEventLoop;

use strict;
use warnings;
use base qw(Milton::EventLoop);
use Milton::t::MockInterface;
use Milton::t::MockController;
use Milton::t::MockCommand;
use Milton::Config;

=head1 NAME

Milton::t::MockEventLoop - Mock EventLoop for testing

=head1 DESCRIPTION

A mock version of Milton::EventLoop that allows injection of mock objects
for testing purposes.

=cut

sub new {
    my ($class, $config, $command, @args) = @_;
    
    # Create a minimal config if none provided
    $config ||= {
        period => 1,
        interface => { package => 'Milton::t::MockInterface' },
        controller => { package => 'Milton::t::MockController' },
        command => { package => 'Milton::t::MockCommand' },
        logging => { enabled => 0 }
    };
    bless $config, 'Milton::Config';
    
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
        $self->{interface} = Milton::t::MockInterface->new;
    } elsif ($key eq 'controller') {
        $self->{controller} = Milton::t::MockController->new({}, $self->{interface});
    }
    
    return;
}

sub _initializeCommand {
    my ($self, $command, @args) = @_;
    $self->{command} = Milton::t::MockCommand->new;
}

1; 
