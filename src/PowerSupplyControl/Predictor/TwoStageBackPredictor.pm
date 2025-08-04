package PowerSupplyControl::Predictor::TwoStageBackPredictor;

use strict;
use warnings qw(all -uninitialized);

use List::Util qw(max min);
use Carp qw(croak);

use base qw(PowerSupplyControl::Predictor::TwoStageThermal);
use PowerSupplyControl::Math::LinearSigmoidWeight;
use PowerSupplyControl::Math::LowPassFilter;

=head1 NAME

PowerSupplyControl::Predictor::TwoStageThermal - Thermal predictor based on back-prediction in a two-stage thermal model

=head1 SYNOPSIS

=head1 DESCRIPTION

This predictor models the hotplate assembly as two first-order thermal stages in series. The
first stage or inner loop models the heating element and the second stage models the rest of
the hotplate assembly. The predictor focuses only on the first stage - the heating element and
applies some mathematics based on a combination of theory and empirical data to predict the
temperate of the hotplate given the history of power inputs and measured temperature of the
heating element.

=head1 METHODS

=head2 new

=cut

=head2 predictTemperature

=cut

sub initialize {
  my ($self) = @_;
  
  my $gradient = $self->{'mixture-gradient'} // -2;
  my $offset = $self->{'mixture-offset'} // -4.6;

  if (!defined $self->{'sigmoid-weight'}) {
    $self->{'sigmoid-weight'} = PowerSupplyControl::Math::LinearSigmoidWeight->new($gradient, $offset);
    $self->debug(10, "new sigmoid weight: gradient: $gradient, offset: $offset");
  } else {
    $self->{'sigmoid-weight'}->initialize($gradient, $offset);
    $self->debug(10, "re-initialized sigmoid weight: gradient: $gradient, offset: $offset");
  }

  if (!defined $self->{'power-lpf'}) {
    $self->{'power-lpf'} = PowerSupplyControl::Math::LowPassFilter->new(tau => $self->{'power-time-constant'} // 6, period => 100);
    $self->debug(10, 'new power lpf: tau: '. $self->{'power-lpf'}->tau);
  } else {
    $self->{'power-lpf'}->reset(undef, tau => $self->{'power-time-constant'} // 6);
    $self->debug(10, 're-initialized power lpf: tau: '. $self->{'power-lpf'}->tau);
  }

  if (!defined $self->{'Th-lpf'}) {
    $self->{'Th-lpf'} = PowerSupplyControl::Math::LowPassFilter->new(tau => $self->{'Th-time-constant'} // 27, period => 100);
    $self->debug(10, 'new Th lpf: tau: '. $self->{'Th-lpf'}->tau);
  } else {
    $self->{'Th-lpf'}->reset(undef, tau => $self->{'Th-time-constant'} // 27);
    $self->debug(10, 're-initialized Th lpf: tau: '. $self->{'Th-lpf'}->tau);
  }

  if (!defined $self->{'deltaP-lpf'}) {
    $self->{'deltaP-lpf'} = PowerSupplyControl::Math::LowPassFilter->new(tau => $self->{'deltaP-time-constant'} // 3, period => 100);
    $self->debug(10, 'new deltaP lpf: tau: '. $self->{'deltaP-lpf'}->tau);
  } else {
    $self->{'deltaP-lpf'}->reset(undef, tau => $self->{'deltaP-time-constant'} // 3);
    $self->debug(10, 're-initialized deltaP lpf: tau: '. $self->{'deltaP-lpf'}->tau);
  }

  $self->{'max-power'} //= 90;

  delete $self->{'last-Th'};
  delete $self->{'last-Tp'};
  delete $self->{'last-power'};
  delete $self->{'last-delta-T'};
  delete $self->{'predict-temperature'};
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $prediction;
  
  # Track maximum power for normalization purposes
  $self->{'max-power'} = max($self->{'max-power'}, $status->{power});

  my $Th_lpf = $self->{'Th-lpf'};
  my $last_Th = $self->{'last-Th'};
  my $real_Th = $status->{temperature};
  if (!defined $last_Th) {
    my $period = $status->{period};
    $prediction = $real_Th;
    $status->{'lpf-prediction'} = $prediction;
    $status->{'back-prediction'} = $prediction;

    $self->{'power-lpf'}->reset($status->{power}, period => $period);
    $Th_lpf->reset($prediction, period => $period);

    $self->{'deltaP-lpf'}->setPeriod($period);
  } else {
    # Calculate effective power and temperature
    my $power = $self->_effectivePower($status);
    $self->{'effective-temperature'} = $self->_effectiveTemperature($status);
    my $lpf_power = $self->{'power-lpf'}->next($power);

    # Do a back-prediction using LPF'd power input
    my $back_prediction = $self->_backPredictTemperature($status, power => $lpf_power);
    $status->{'back-prediction'} = $back_prediction;

    # Apply a low pass filter to the heater input temperature
    my $lpf_Th = $Th_lpf->next($real_Th);
    $status->{'lpf-prediction'} = $lpf_Th;

    # Calculate delta-P and LPF to determine mixing factor
    # Normalize delta-P so we can generalize the sigmoid weight parameters
    my $norm_delta_P = abs($status->{power} - $self->{'last-power'}) / $self->{'max-power'};
    my $lpf_delta_P = $self->{'deltaP-lpf'}->next($norm_delta_P);
    
    # Prevent illegal log of 0
    $lpf_delta_P = max(0.0001, $lpf_delta_P);

    # Determine the weighting to apply to the two predictions
    # Linear+Sigmoid
    # Take the logarithm so the scale works how we expect
    my $weight = $self->{'sigmoid-weight'}->weight(log($lpf_delta_P));
    $status->{weight} = $weight;

    # Combine the two predictions using a weighted average
    $prediction = $weight * $back_prediction + (1 - $weight) * $lpf_Th;

    # Final sanity check
    # If Th is higher than Tp and delta-Th is positive, then we're not cooling down!
    if ($real_Th > $prediction
     && $real_Th - $last_Th > 0
     && $prediction < $self->{'last-prediction'}) {
      $prediction = $self->{'last-prediction'};
#      $self->warning('Heater is heating up. Heuristic override on cooling prediction.');
    }
  }

  # Save state for the next prediction
  $self->{'last-Th'} = $real_Th;
  $self->{'last-power'} = $status->{power};
  $status->{'predict-temperature'} = $prediction;
  $self->{'last-prediction'} = $prediction;
  
  # Assume that our prediction is better than a plain low-pass filter, so seed the
  # filter with out better prediction
  if ($self->{'tuning-lpf-reset'}) {
    # Tuning goal is to come up with a delay parameter that keeps the prediction close
    # when the previous prediction was close, so use device temperature as the seed
    # when tuning the low pass filter.
    $Th_lpf->reset($status->{'device-temperature'});
  } else {
    $Th_lpf->reset($prediction);
  }

  return $prediction;
}

=head2 tune

=cut

sub tune {
  my ($self, $samples) = @_;

  $self->info('INFO: Tuning TwoStageBackPredictor primary predictor');

  my $primary = $self->_tune3D($samples
                             , 'R-int', 'C-heater', 'power-time-constant'
                             , [ [ 0.001, 100 ], [ 0.3, 100 ], [ 0.001, 10 ] ]
                             , prediction => 'back-prediction'
                             , 'lower-constraint' => [ 0.001, 0.3, 0.001 ],
                             , 'upper-constraint' => [ 100, 100, 10 ]
                             , threshold => 0.001,
                             );

  $self->info('INFO: Tuning TwoStageBackPredictor low pass filter secondary predictor');
  $self->{'tuning-lpf-reset'} = 1;
  my $lpf_tune = $self->_tune1D($samples, 'Th-time-constant'
                              , [ [ 0, 200 ] ]
                              , prediction => 'lpf-prediction'
                              , 'lower-constraint' => [ 0.001 ]
                              , 'upper-constraint' => [ 2000 ]
                              , threshold => 0.001
                              );
  delete $self->{'tuning-lpf-reset'};

  $self->info('INFO: Tuning TwoStageBackPredictor mixture parameters');
  my $mixture = $self->_tune3D($samples
                             , 'deltaP-time-constant', 'mixture-gradient', 'mixture-offset'
                             , [ [ 0.01, 30 ], [ -100, 100 ], [ -100, 100 ] ]
                             , 'lower-constraint' => [ 0.01, undef, undef ]
                             , threshold => 0.001
                             );

  my $tuned = { %$primary, %$lpf_tune, %$mixture };

  return $tuned;
}

1;