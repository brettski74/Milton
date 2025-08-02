package PowerSupplyControl::Predictor::TwoStageThermal;

use strict;
use warnings qw(all -uninitialized);

use List::Util qw(max min);
use Carp qw(croak);

use base qw(PowerSupplyControl::Predictor);

=head1 NAME

PowerSupplyControl::Predictor::TwoStageThermal - Two stage thermal predictor

=head1 SYNOPSIS

=head1 DESCRIPTION

This predictor is a two stage thermal predictor. It uses two first order thermal models to
predict the temperature of the hotplate over time. It models the heat capacity of the heating
element and the thermal resistance between the heating element and the rest of the hotplate
assembly. It then models the heat capacity of the hotplate assembly and the thermal resistance
between the hotplate assembly and the ambient environment. With properly tuned parameters,
this predictor should be able to predict the lag between power inputs and temperature as well
as the offset between heating element temperature and hotplate temperature - hopefully!

=head1 METHODS

=head2 new

=cut

sub new {
  my ($class, %options) = @_;

  my $self = { %options };

  bless $self, $class;

  # Check mandatory parameters. If any are missing, switch to the empty predictor.
  foreach my $mandatory (qw(R-int R-ext-gradient R-ext-intercept C-plate C-heater)) {
    if (!exists $self->{$mandatory}) {
      bless $self, 'PowerSupplyControl::Predictor::TwoStageThermal::Empty';
      last;
    }
  }

  return $self;
}

=head2 setPredictedTemperature

=cut

sub setPredictedTemperature {
  my ($self, $temperature) = @_;

  $self->{'predict-temperature'} = $temperature;
}

=head2 predictTemperature

=cut

sub predictTemperature {
  my ($self, $status) = @_;

  my $back_prediction;
  my $forward_prediction;
  my $back_iir;

  if (!defined $self->{'last-Th'}) {
    $back_prediction = $status->{temperature};
    $forward_prediction = $back_prediction;
    $back_iir = $back_prediction;
  } else {
    $status->{'effective-temperature'} = $self->_effectiveTemperature($status);
    $status->{'effective-power'} = $self->_effectivePower($status);

    ($back_prediction, $back_iir) = $self->_backPredictTemperature($status);
    $forward_prediction = $self->_forwardPredictTemperature($status);
  }

  # Some kind of weighted average needed here... Let's just start with alpha = 0.5 for now.
  #my $alpha = 0.5;
  #my $prediction = $alpha * $back_prediction + (1 - $alpha) * $forward_prediction;
  $self->{'predict-temperature'} = $back_prediction;
  $status->{'predict-temperature'} = $back_prediction;
  $status->{'back-prediction'} = $back_prediction;
  $status->{'forward-prediction'} = $forward_prediction;
  $self->{'back-iir'} = $status->{'back-iir'} = $back_iir;

  # Save state
  $self->{'last-Th'} = $status->{temperature};
  $status->{'last-Tp'} = $self->{'last-Tp'};
  #$self->{'last-Tp'} = $back_iir;
  #$self->{'last-Tp'} = $status->{'device-temperature'};   # Cheating!!! Testing Only!!!
  $self->{'last-Tp'} = $status->{'predict-temperature'};
  $self->{'last-power'} = $status->{power};

  return $back_iir;
}

sub _effectiveTemperature {
  my ($self, $status) = @_;

  my $last_Th = $self->{'last-Th'};
  if (!defined $last_Th) {
    return $status->{temperature};
  }

  my $delta_T = $self->{'last-delta-T'};
  my $last_power = $self->{'last-power'};
  my $power = $status->{power};
  my $threshold = $self->{'power-change-threshold'} // 0.05;

  # If power hasn't changed much or we don't have a delta-T yet, then return the average
  # temperature of the last two samples
  if (!defined($delta_T) || abs($power - $last_power)/max($power, $last_power) < $threshold) {
    $self->{'last-delta-T'} = $status->{temperature} - $self->{'last-Th'};
    return ($status->{temperature} + $self->{'last-Th'}) / 2;
  }

  # Determine the temperature at the time of the change
  my $delay = $status->{'last-update-delay'} // 0;
  my $period = $status->{period};
  my $change_T = $last_Th + $delta_T * $delay/$period;

  # Calculate a time-weighted average assuming that we linearly transitioned to the change temperature
  # then linearly transitioned to the current temperature.
  my $effective_temperature = ($change_T + ($last_Th*$delay + ($period-$delay)*$status->{temperature})/$period) / 2;

  # Calculate our delta-T from change temperature to current temperature and scale to a full sample period
  $self->{'last-delta-T'} = ($status->{temperature} - $change_T) * $period/($period - $delay);

  return $effective_temperature;
}

sub _effectivePower {
  my ($self, $status) = @_;

  my $last_power = $self->{'last-power'};

  if (!defined $last_power) {
    return $status->{power};
  }

  my $effective_power;
  my $power = $status->{power};
  my $period = $status->{period};
  my $delay = $status->{'last-update-delay'} // 0;
  if ($delay > $period) {
    $delay = $period;
  }

#  my $variance = abs($power - $last_power)/max($power, $last_power);
#  if ($delay < $period && $variance > 0.05) {
#    my $transition = $self->{'transition-time'} // 0;
#    my $transition_power = 0;
#    if ($transition > 0) {
#      my $resistance = $status->{resistance};
#      my $vmin = min($last_power, $power) / $resistance;
#      my $vmax = max($last_power, $power) / $resistance;
#      my $delta_v = $vmax - $vmin;
      
#      $transition_power = ($vmin*$vmin + $vmin*$delta_v + $delta_v*$delta_v/3) / $resistance;
#    }

#    if ($delay + $transition > $period) {
#      $transition = $period - $delay;
#    }

#    $effective_power = ($delay * $last_power
#                      + $transition * $transition_power
#                      + ($period - $delay - $transition) * $power
#                      ) / $period;
#  } else {
    $effective_power = ($delay * $last_power + ($period - $delay) * $power) / $period;
#  }

  $status->{'effective-power'} = $effective_power;

  return $effective_power;
}

sub _backPredictTemperature {
  my ($self, $status) = @_;

  my $real_delta_T = $status->{temperature} - $self->{'last-Th'};
  my $power = $status->{'effective-power'};
  my $T_heater = $status->{'effective-temperature'};
#  my $loss_factor = $self->{'loss-factor'} // 0.95;

  my $iir_power = $self->{'iir-power'} // $power;

  my $period = $status->{period};
  my $R_int = $self->{'R-int'};
  my $C_heater = $self->{'C-heater'};

  my $tau = $R_int * $C_heater;
  my $alpha = $period / ($period + $tau);

  my $power_tau = $tau*$tau;
  my $power_alpha = $period / ($period + $power_tau);

  $iir_power = $power_alpha * $power + (1 - $power_alpha) * $iir_power;

  # Back-calculate the plate offset that is needed to account for any excess energy input
  my $T_plate = $T_heater - ($power - $C_heater * $real_delta_T/$period) * $R_int;
  my $back_iir = $alpha * $T_plate + (1 - $alpha) * $self->{'back-iir'};
  my $T_plate2 = $T_heater - ($iir_power - $C_heater * $real_delta_T/$period) * $R_int;

  $self->{'iir-power'} = $iir_power;
  $status->{'iir-power'} = $iir_power;
  $self->{'back-iir'} = $back_iir;
  $status->{'back-iir'} = $back_iir;
  
  my $prediction = ($T_plate2 + $back_iir) / 2;

  return ($prediction, $back_iir);
}

sub _forwardPredictTemperature {
  my ($self, $status) = @_;

  my $T_heater = $status->{'effective-temperature'};
#  my $T_plate = $status->{'predict-temperature'};
  my $T_plate = $self->{'last-Tp'};
  my $T_rel = $T_plate - $status->{ambient};

  my $R_int = $self->{'R-int'};
  my $R_ext = $self->{'R-ext-gradient'} * $T_rel + $self->{'R-ext-intercept'};
  my $C_plate = $self->{'C-plate'};
  my $period = $status->{period};

  my $delta_Tp = (($T_heater - $T_plate)/$R_int - $T_rel/$R_ext) * $period / $C_plate;

  return $T_plate + $delta_Tp;
}

sub initialize {
  my ($self) = @_;

  delete $self->{'last-Th'};
  delete $self->{'last-Tp'};
  delete $self->{'last-power'};
  delete $self->{'last-delta-T'};
  delete $self->{'predict-temperature'};
}

=head2 tune

=cut

sub tune {
  my ($self, $samples) = @_;

  print "WARN: I am using iir-power! And hopefully using correct last-Tp!\n";

  my $inner = $self->_tune2D($samples
                           , 'R-int', 'C-heater'
                           , [ [ 0.001, 100 ], [ 0.001, 100 ] ]
                           , prediction => 'back-prediction'
                           , lower_constraint => [ 0.001, 0.001 ],
                           , threshold => 0.001,
                           , upper_constraint => [ 100, 100 ]
                           );

  my $outer = $self->_tune3D($samples
                           , 'R-ext-gradient', 'R-ext-intercept', 'C-plate'
                           , [ [ -100, 100 ], [ 0.01, 100 ], [ 0.01, 100 ] ]
                           , prediction => 'forward-prediction'
                           , lower_constraint => [ undef, 0.001, 0.001 ]
                           , threshold => 0.001
                           );

  my $tuned = { %$inner, %$outer };

  return $tuned;
}

package PowerSupplyControl::Predictor::TwoStageThermal::Empty;

# provide some simple prediction model for an un-tuned predictor so that we can tune it
# afterwards
sub predictTemperature {
  my ($self, $status) = @_;

  if (!exists $self->{'predict-temperature'}) {
    $self->{'predict-temperature'} = $status->{temperature};
    $status->{'predict-temperature'} = $status->{temperature};
    return $status->{temperature};
  }

  # Really simple model - just apply a proportional loss factor to the temperature and a low-pass IIR filter to
  # delay the heating element impacts on hotplate temperature.
  my $tau = $self->{tau} // 27;
  my $loss = $self->{'loss-factor'} // 0.1;
  my $alpha = $status->{period} / ($status->{period} + $tau);
  my $temperature = $status->{ambient} + (1-$loss) * ($status->{temperature} - $status->{ambient});

  my $prediction = $alpha * $temperature + (1-$alpha) * $self->{'predict-temperature'};
  $self->{'predict-temperature'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub tune {
  my ($self, $samples) = @_;

  # We need to ensure that predictTemperature has sufficient parameters to run during
  # tuning. Back-prediction parameters are tuned first, so we don't need to provide them,
  # but provide some sane defaults for forward-prediction so that predictTemperature will
  # work during the back-prediction tuning.
  $self->{'R-ext-gradient'} = -0.005;
  $self->{'R-ext-intercept'} = 5;
  $self->{'C-plate'} = 100;

  # re-bless ourselves into the correct class
  bless $self, 'PowerSupplyControl::Predictor::TwoStageThermal';

  # Now do the real tuning!
  return $self->tune($samples);
}

1;