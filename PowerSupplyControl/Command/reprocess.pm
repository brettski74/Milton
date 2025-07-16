package PowerSupplyControl::Command::reprocess;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);

use base qw(PowerSupplyControl::Command);
use PowerSupplyControl::ValueTools qw(readCSVData);

sub new {
  my ($class, $config, $interface, $controller, $filename, $command, @args) = @_;
  my $self = $class->SUPER::new($config, $interface, $controller);

  my $package = "PowerSupplyControl::Command::$command";

  eval "use $package";
  if ($@) {
    croak "Failed to load command $command: $@";
  }
  $self->{package} = $package;
  $self->{filename} = $filename;
  $self->{'command-name'} = $command;
  $self->{args} = [ @args ];

  return $self;
}

sub defaults {
  return { 'link-records' => 1 };
}

sub preprocess {
  my ($self, $status) = @_;

  my $cfg = $status->{'event-loop'}->{config};
  if (PowerSupplyControl::Config->configFileExists("command/$self->{'command-name'}.yaml")) {
    $cfg->merge("command/$self->{'command-name'}.yaml", 'command', $self->{'command-name'});
  }

  my $config = $cfg->clone('command', $self->{'command-name'});

  $self->{command} = $self->{package}->new($config, $self->{interface}, $self->{controller}, $self->{args});

  return $self;
}

sub postprocess {
  my ($self, $status) = @_;

  my $history = readCSVData($self->{filename});

  if ($self->{config}->{'link-records'}) {
    for (my $i=1; $i < @$history; $i++) {
      $history->[$i-1]->{'next'} = $history->[$i];
      $history->[$i]->{'last'} = $history->[$i-1];
    }
  }

  return $self->{command}->postprocess($status, $history);
}

1;