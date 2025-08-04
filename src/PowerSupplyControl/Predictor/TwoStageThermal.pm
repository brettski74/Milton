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

NOTE THAT THIS PREICTOR DOES NOT CURRENTLY WORK!

It's still here because some of the code is the basis of the TwoStageBackPredictor, which
works really well. I'll clean this all up in a later commit.

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

  my $self = $class->SUPER::new(%options);
  $self->{class} = $class;

  # Check mandatory parameters. If any are missing, switch to the empty predictor.
  foreach my $mandatory ($self->mandatoryParameters) {
    if (!exists $self->{$mandatory}) {
      bless $self, 'PowerSupplyControl::Predictor::TwoStageThermal::Empty';
      last;
    }
  }

  return $self;
}

sub mandatoryParameters {
  return qw(R-int R-ext-gradient R-ext-intercept C-plate C-heater);
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
  my $prediction = $back_prediction;
  $status->{'back-prediction'} = $back_prediction;
  $status->{'forward-prediction'} = $forward_prediction;
  $self->{'back-iir'} = $status->{'back-iir'} = $back_iir;

  # Save state
  $self->{'last-Th'} = $status->{temperature};
  $status->{'last-Tp'} = $self->{'last-Tp'};
  #$self->{'last-Tp'} = $back_iir;
  #$self->{'last-Tp'} = $status->{'device-temperature'};   # Cheating!!! Testing Only!!!
  my $first_difference = $status->{'predict-temperature'} - $self->{'last-Tp'};
  my $second_difference = $self->{'first-difference'} - $first_difference;
  $self->{'first-difference'} = $first_difference;
  $self->{'second-difference'} = $second_difference;
  my $delta_P = abs($status->{'effective-power'} - $self->{'last-power'});
  my $dpalpha = 0.3333333333333;
  my $dpiir = $delta_P * $dpalpha + (1 - $dpalpha) * $self->{'dpiir'};
  $self->{'dpiir'} = $dpiir;

  # Hack - need to get max power from somewhere

  $self->{'last-Tp'} = $status->{'predict-temperature'};
  $self->{'last-power'} = $status->{power};

  $status->{'predict-temperature'} = $back_prediction;
  $self->{'predict-temperature'} = $back_prediction;

  return $self->{'predict-temperature'};
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

  $effective_power = ($delay * $last_power + ($period - $delay) * $power) / $period;

  $status->{'effective-power'} = $effective_power;

  return $effective_power;
}

sub _backPredictTemperature {
  my ($self, $status, %args) = @_;

  # Heating element temperature
  # May be adjusted for estimated variation between samples
  my $temperature = $args{temperature} // $status->{'effective-temperature'} // $status->{temperature};

  # Input power
  # May be adjusted for variation between samples
  my $power = $args{power} // $status->{'effective-power'} // $status->{power};

  # Real heating element temperature change since last sample
  my $delta_T = $args{'delta-T'} // $status->{temperature} - $self->{'last-Th'};

  # Sample period - usually should be constant. Unsure how well this works with varilable sample periods.
  my $period = $args{period} // $status->{period};

  # Heating element heat capacity
  my $C_heater = $args{'C-heater'} // $self->{'C-heater'};

  # Thermal resistance between heating element and the surrounding hotplate assembly
  my $R_int = $args{'R-int'} // $self->{'R-int'};

  return $temperature - ($power - $C_heater * $delta_T/$period) * $R_int;
}

sub _forwardPredictTemperature {
  my ($self, $status, %args) = @_;

  # Heating element temperature
  # May be adjusted for estimated variation between samples
  my $temperature = $args{temperature} // $status->{'effective-temperature'} // $status->{temperature};

  # Hotplate temperature
  # Best guess. Usually from the most recent prediction.
  my $T_plate = $args{T_plate} // $self->{'last-Tp'};

  # Ambient temperature
  my $ambient = $args{ambient} // $status->{ambient};

  # Thermal resistance between the heating element and the hotplate assembly
  my $R_int = $args{'R-int'} // $self->{'R-int'};

  # Thermal resistance between the hotplate assembly and the ambient environment
  # Typically varies with temperature and may be approximated with a linear function
  my $gradient = $args{'R-ext-gradient'} // $self->{'R-ext-gradient'};
  my $intercept = $args{'R-ext-intercept'} // $self->{'R-ext-intercept'};
  my $T_rel = $args{T_rel} // $T_plate - $ambient;
  my $R_ext = $args{R_ext} // $gradient * ($T_plate - $ambient) + $intercept;

  # Heat capacity of the hotplate assembly
  my $C_plate = $args{'C-plate'} // $self->{'C-plate'};

  # Sample period - usually should be constant. Unsure how well this works with varilable sample periods.
  my $period = $args{period} // $status->{period};

  return $T_plate + (($temperature - $T_plate)/$R_int - $T_rel/$R_ext) * $period / $C_plate;
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
  bless $self, $self->{class} // 'PowerSupplyControl::Predictor::TwoStageThermal';

  # Now do the real tuning!
  return $self->tune($samples);
}

1;