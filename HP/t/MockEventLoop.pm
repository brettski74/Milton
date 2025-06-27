package HP::t::MockEventLoop;

use strict;
use warnings;
use base qw(HP::EventLoop);
use HP::t::MockInterface;
use HP::t::MockController;
use HP::t::MockCommand;
use HP::Config;

=head1 NAME

HP::t::MockEventLoop - Mock EventLoop for testing

=head1 DESCRIPTION

A mock version of HP::EventLoop that allows injection of mock objects
for testing purposes.

=cut

sub new {
    my ($class, $config, $command, @args) = @_;
    
    # Create a minimal config if none provided
    $config ||= {
        period => 1,
        interface => { package => 'HP::t::MockInterface' },
        controller => { package => 'HP::t::MockController' },
        command => { package => 'HP::t::MockCommand' },
        logging => { enabled => 0 }
    };
    bless $config, 'HP::Config';
    
    my $self = $class->SUPER::new($config, $command, @args);
    
    return $self;
}

sub _now {
  my ($self) = @_;

  if (exists $self->{'last-timer-status'}) {
    return $self->{'last-timer-status'}->{'now'};
  }
  return 0;
}

sub _time {
  my ($self) = @_;

  if (exists $self->{'last-timer-status'}) {
    return $self->{'last-timer-status'}->{'time'} || $self->_now;
  }
  return $self->_now;
}

sub _initializeObject {
    my ($self, $key) = @_;
    
    # Use mock objects for testing
    if ($key eq 'interface') {
        $self->{interface} = HP::t::MockInterface->new;
    } elsif ($key eq 'controller') {
        $self->{controller} = HP::t::MockController->new({}, $self->{interface});
    }
    
    return;
}

sub _initializeCommand {
    my ($self, $command, @args) = @_;
    $self->{command} = HP::t::MockCommand->new;
}

1; 