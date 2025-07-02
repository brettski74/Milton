package HP::Controller::FeedForward;

use strict;
use Carp qw(croak);
use base qw(HP::Controller::RTDController);
use Statistics::Regression;
use HP::ThermalModel;

=head1 NAME

HP::Controller::FeedForward - Implements a FeedForward controller that uses a thermal model to predict the power required to reach the next target temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Create a new feed forward controller instance.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Verify mandatory parameters
  croak "HP::resistance not specified." unless $config->{resistance};
  croak "capacity not specified." unless $config->{capacity};

  # Set defaults if required
  $self->{ambient} = $config->{ambient} || 20.0;

  # Create the regression model
  $self->{regression} = Statistics::Regression->new('Feed-forward Regression', [ 'power', 'rel_temp' ]);

  # Create the thermal model
  $self->{model} = HP::ThermalModel->new($self);

  # How many samples until we re-evaluate kp and kt?
  $self->{countdown} = $self->{'initial-regression-samples'} || $self->{'regression-samples'} || 10;

  # IIR filter coefficient for smoothing the power output
  $self->{alpha} = $self->{alpha} || 0.3;

  # Keep a log of the status every sample period
  $self->{log} = [];

  return $self;
}

=head2 getRequiredPower($status, $target_temp)

Calculate the power required to achieve a certain hotplate temperature by the next sample period.

=cut

sub getRequiredPower {
  my ($self, $status, $target_temp) = @_;

  # Set the power to achieve the target temperature
  my $power = $self->{model}->estimatePower($status, $target_temp);
  $power = $self->_filterOutputPower($power);

  return $power;
}

sub _filterOutputPower {
  my ($self, $power) = @_;

  if (exists $self->{power_iir}) {
    $power = $self->{alpha} * $power + (1 - $self->{alpha}) * $self->{power_iir};
  }

  $self->{power_iir} = $power;

  return $power;
}

sub _logStatus {
  my ($self, $status) = @_;

  if (@{$self->{log}}) {
    my $last = $self->{log}[-1];
    my $delta_T = $status->{temperature} - $last->{temperature};
    $last->{'delta-T'} = $delta_T;
    $self->{regression}->addPoint($delta_T, $last);
    $self->{countdown}--;

    if ($self->{countdown} <= 0) {
      my ($kp, $kt) = $self->{regression}->theta();
      $self->{model}->setKp($kp);
      $self->{model}->setKt($kt);
      $self->{countdown} = $self->{'regression-samples'} || 20;
    }
  }

  push @{$self->{log}}, $status;


}

1;
