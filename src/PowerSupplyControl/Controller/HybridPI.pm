package PowerSupplyControl::Controller::HybridPI;

use strict;
use warnings qw(all -uninitialized);

use base 'PowerSupplyControl::Controller::RTDController';

use PowerSupplyControl::Math::Util qw(sgn);

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{kp} //= 2.47;
  $self->{ki} //= 0.1;
  $self->{kaw} //= $self->{ki} / $self->{kp};

  # Only designed to work with the DoubleLPFPower predictor.
  croak 'DoubleLPFPower predictor is required' unless $self->{'predictor'}->isa('PowerSupplyControl::Predictor::DoubleLPFPower');

  return $self;
}

sub getRequiredPower {
  my ($self, $status) = @_;

  my $ff_power = $self->{predictor}->predictPower($status);
  my ($pmin, $pmax) = $self->{interface}->getPowerLimits();

  # Note that predict-temperature is the temperature we're trying to control and now-temperature is the
  # expected temperature for *now* as per the reflow profile.
  my $error = $status->{'predict-temperature'} - $status->{'now-temperature'};

  my $integral = $self->{integral} //= 0;
  my $iterm = $error * $self->{ki} * $status->{period};
  $integral += $iterm;

  my $power_unsat = $ff_power + $self->{kp} * $error + $self->{ki} * $integral;
  my $power_sat = $power_unsat;

  if ($power_unsat > $pmax) {
    $power_sat = $pmax;
    if ($error > 0) {
      $integral = $integral - $iterm;
    }
  } elsif ($power_unsat < $pmin) {
    $power_sat = $pmin;
    if ($error < 0) {
      $integral = $integral - $iterm;
    }
  }

  # Anti-windup correction
  $integral += $self->{kaw} * ($power_sat - $power_unsat);

  $self->{integral} = $integral;

  return $power_sat;
}

1;