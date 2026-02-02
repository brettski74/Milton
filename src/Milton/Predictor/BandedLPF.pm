package Milton::Predictor::BandedLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Predictor);
use Milton::Math::PiecewiseLinear;

use Milton::DataLogger qw(get_namespace_debug_level);
use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_DATA => 100;

=encoding utf8

=head1 NAME

Milton::Predictor::BandedLPF - Banded Low Pass Filter Temperature Predictor

=head1 SYNOPSIS

  use Milton::Predictor::BandedLPF;
  
  # Create a predictor with default parameters
  my $predictor = Milton::Predictor::BandedLPF->new();
  
  # Create a predictor with custom temperature bands
  my $predictor = Milton::Predictor::BandedLPF->new(
    bands => [
      { temperature => 25,  'inner-tau' => 3.0, 'outer-tau' => 400, 'power-tau' => 120, 'power-gain' => 3.6 },
      { temperature => 100, 'inner-tau' => 2.5, 'outer-tau' => 300, 'power-tau' => 115, 'power-gain' => 2.8 },
      { temperature => 200, 'inner-tau' => 2.2, 'outer-tau' => 270, 'power-tau' => 112, 'power-gain' => 2.5 }
    ]
  );
  
  # Predict hotplate temperature from heating element temperature
  my $status = {
    temperature => 150,    # Heating element temperature (°C)
    ambient     => 25,     # Ambient temperature (°C)
    period      => 1.5     # Time between successive samples in seconds
  };
  
  my $predicted_temp = $predictor->predictTemperature($status);

=head1 DESCRIPTION

C<Milton::Predictor::BandedLPF> is an advanced temperature prediction model that estimates hotplate 
temperature based on measurements of the heating element temperature. This predictor uses a banded 
approach with piecewise linear interpolation to model non-linear variations in thermal properties 
across the operating temperature range, providing superior accuracy compared to simpler models.

The prediction model works by:

=over

=item 1. **Temperature Banding**

Divides the operating temperature range into bands, each with its own set of thermal parameters.

=item 2. **Piecewise Linear Interpolation**

Uses L<Milton::Math::PiecewiseLinear> estimators to smoothly interpolate thermal parameters 
between temperature bands.

=item 3. **Dual Low-Pass Filtering**

Applies cascaded inner and outer low-pass filters similar to L<Milton::Predictor::DoubleLPF>, 
but with temperature-dependent time constants.

=item 4. **Power Prediction Capability**

Includes piecewise linear estimators for predicting how power inputs translate into heating 
element temperatures, enabling simulation and feed-forward control.

=back

The mathematical model uses the same cascaded approach as DoubleLPF but with temperature-dependent parameters:

    # Inner filter: heating element -> hotplate
    inner_tau = inner_tau_estimator(last_prediction)
    alpha_inner = period / (period + inner_tau)
    intermediate_temp = temperature * alpha_inner + (1 - alpha_inner) * last_prediction
    
    # Outer filter: hotplate -> ambient
    outer_tau = outer_tau_estimator(intermediate_temp)
    alpha_outer = period / (period + outer_tau)
    prediction = ambient * alpha_outer + (1 - alpha_outer) * intermediate_temp

Where the time constants are estimated using piecewise linear interpolation based on temperature.

Power to temperature prediction is based on a power-to-temperature gain factor and a low-pass filter to model
the delay between input power and the resulting heating element temperatures. The predicted temperature is
that of the heating element, which can then be fed into the hotplate template prediction model to predict
hotplate temperatures. The mathematical model can be summarised as:

    # Estimate steady-state temperature for give power level
    power_gain = power_gain_estimator(heating_element_temperature)
    ss_temp = ambient + power_gain * power
    
    # Apply low-pass filter to model delay between power input and temperature response
    power_tau = power_tau_estimator(heating_element_temperature)
    alpha_power = period / (period + power_tau)
    prediction = ss_temp * alpha_power + (1 - alpha_power) * last_hotplate_temperature

Where the last_hotplate_temperature can either be drawn from various sources. In feed-forward control, this
will use the most recent measurement of hotplate temperature. In simulation, this will use the most recent
prediction of hotplate temperature. Note that the low-pass filter here models the steady-state temperature
as pulling the current hotplate temperature towards the steady-state temperature.

or the most recent 

=head1 PARAMETERS

=head2 bands

Array reference containing temperature band definitions. Each band is a hash reference with the following keys:

=over

=item C<temperature>

The center temperature for this band (°C)

=item C<inner-tau>

Time constant for heat transfer from heating element to hotplate at this temperature (seconds)

=item C<outer-tau>

Time constant for heat loss to ambient at this temperature (seconds)

=item C<power-tau>

Time constant for power-to-temperature response at this temperature (seconds, optional)

=item C<power-gain>

Gain factor for power-to-temperature response at this temperature (°C/W, optional)

=back

=over

=item * Default

Single band at 25°C with inner-tau=3.357, outer-tau=2000

=item * Typical Configuration

3-5 bands covering the operating temperature range (25°C to 250°C)

=item * Tuning

The current implementation generates bands automatically based on typical solder reflow profiles. This
divides the operating temperature range into 4 bands, plus an additional ambient temperature "band" to
flatten the parameter variation at low temperatures. The generated bands are generally described as:

* Up to 100°C

* 100-150°C

* 150-200°C

* 200-250°C

Typically, tuning data doesn't go up to 250°C, so the centre temperature for this band is set to 210°C.

There's no reason why finer bands can't be used. From a tuning perspective, generating tuned parameters
for finer temperature bands does require some attention to how you get sufficient and suitable tuning
data.  The class implementation doesn't place any hard limits on the number of bands, although very high
numbers of bands could cause performance issues and current empirical experience suggests that the gains
from more than 4 bands may be limited - at least with aluminium PCB hotplates. Whether there may be
benefit from more temperature bands for substrates with more complicated thermal behaviour like FR4 is
not currently known.

=back

=head1 CONSTRUCTOR

=head2 new(%options)

Creates a new BandedLPF predictor instance.

=over

=item C<bands>

Array reference of temperature band definitions (default: single band at 25°C)

=item C<logger> (Optional)

An object implementing the L<Milton::DataLogger> interface that may be used for error, information or debug output.

=back

=head1 METHODS

=head2 predictTemperature($status)

Predicts the hotplate temperature based on the current heating element temperature and system state.

=over

=item C<$status>

Status hash containing details of the current system state. The following keys are used by this method:

=over

=item C<ambient>

Ambient temperature (°C)

=item C<period>

Time period since last prediction (seconds)

=item C<temperature>

Current heating element temperature (°C)

=back

=item Return Value

Predicted hotplate temperature (°C)

=item Side Effects

Updates C<last-prediction> in this object and C<predict-temperature> in C<$status>

=back

=head2 predictHeatingElement($status)

Predicts the heating element temperature based on power input. This method requires power-tau and 
power-gain parameters to be defined in the temperature bands.

=over

=item C<$status>

Status hash containing power input and system state

=item Return Value

Predicted heating element temperature (°C) or undef if power parameters not available

=item Side Effects

Updates C<last-heating-element> in this object and C<predict-heating-element> in C<$status>

=back

=head2 predictPower($status)

Predicts the power required to achieve a target temperature at a specified time in the future. 
Uses binary search to find the optimal power level, taking into account the current thermal 
state and system dynamics.

This method is primarily used in feed-forward control to provide stable control signals and 
anticipate upcoming changes in heating requirements from reflow profiles. By looking ahead 
multiple sample periods, it helps avoid abrupt changes in power input and reduces over/undershoot 
that may occur at sudden changes in the required heating rate.

=over

=item C<$status>

Status hash containing target temperature and system state.  The following keys are used:

=over

=item C<anticipate-temperature>

Target temperature to achieve (°C). If not specified, falls back to C<then-temperature>.

=item C<anticipate-period>

The number of seconds to look ahead. This is usually an integer multiple of the C<period>.
If not specified, falls back to C<period>.

=item C<predict-temperature>

Current predicted hotplate temperature (°C)

=item C<temperature>

Current heating element temperature (°C)

=item C<ambient>

Ambient temperature (°C)

=item C<period>

Time period between samples (seconds)

=back

=item Return Value

Required power level (W) to achieve the target temperature, or 0 if power parameters not available

=item Side Effects

None

=back

=head3 Anticipation Feature

The anticipation feature allows the predictor to look ahead multiple sample periods when 
calculating required power. This is particularly useful in feed-forward control for:

=over

=item * **Stable Control**:

Looking further ahead helps smooth the control signal by increasing the time and/or temperature
difference from the current state to the target state. This reduces variability in the control
signal due to small offset errors in previous predictions and spreads the correction for those
errors over more sample periods.

=item * **Profile Following**:

Abrupt changes in the required heating rate can cause undershoot or overshoot for a variety of
reasons including thermal inertia and the power limitations of the supply. By looking further
ahead, the feed forward controller can better anticipate the required power changes and start
adjusting the behaviour of the supply ahead of time to dampen the effects of thermal inertia
and spread power increases over more sample periods.

=back

Anticipation is enabled by setting the C<anticipate-temperature> and C<anticipate-period> values
in the status hash. The current implementation does this in the L<Milton::Command> class currently
executing, although future implementations may clean up this design so that this feature can be
controlled from the L<Milton::Controller> class, which is probably a more appropriate place for
it.

=head2 initialize()

Resets the predictor's internal state and ensures all parameters are properly initialized as 
piecewise linear estimators. This is primarily used during tuning, since the main tuning algorithm
doesn't understand piecewise linear estimators and expects to try sets of parameter values by setting
scalar class attributes. This method transforms those scalar parameter values into the piecewise
linear estimator objects that the class expects to have.

=head2 tune($samples, %args)

Tunes the predictor parameters using historical temperature data. This method automatically 
generates temperature bands based as described above and tunes parameters for each band separately.

=over

=item C<$samples>

Array reference of historical temperature samples with power data

=item C<%args>

Additional tuning options passed to the underlying tuning algorithms

=item Return Value

Hash reference with tuned band definitions

=item Side Effects

Updates the temperature bands and all piecewise linear estimators to the tuned values.

=back

=head2 description()

Returns a human-readable description of the predictor with parameter ranges across all bands.

=head1 USAGE EXAMPLES

=head2 Basic Usage

  use Milton::Predictor::BandedLPF;
  
  my $predictor = Milton::Predictor::BandedLPF->new();
  
  # Predict temperature during heating
  my $status = {
    temperature => 180,  # Heating element at 180°C
    ambient     => 25,   # Room temperature
    period      => 1.5   # 1.5 seconds since last update
  };
  
  my $hotplate_temp = $predictor->predictTemperature($status);
  print "Predicted hotplate temperature: ${hotplate_temp}°C\n";

=head2 Custom Temperature Bands

  # Create predictor with custom temperature bands
  my $predictor = Milton::Predictor::BandedLPF->new(
    bands => [
      { temperature => 25,  'inner-tau' => 3.31, 'outer-tau' => 403, 'power-gain' => 3.60, 'power-tau' => 125 },
      { temperature => 55,  'inner-tau' => 3.31, 'outer-tau' => 403, 'power-gain' => 3.60, 'power-tau' => 125 },
      { temperature => 125, 'inner-tau' => 3.54, 'outer-tau' => 262, 'power-gain' => 3.54, 'power-tau' => 120 },
      { temperature => 175, 'inner-tau' => 3.64, 'outer-tau' => 209, 'power-gain' => 2.84, 'power-tau' => 107 },
      { temperature => 210, 'inner-tau' => 3.98, 'outer-tau' => 156, 'power-gain' => 2.60, 'power-tau' => 102 }
    ]
  );

=head2 Power Prediction

  # Predict power required for target temperature
  my $status = {
    'then-temperature'       => 200,  # Target temperature
    'predict-temperature'    => 150,  # Current hotplate temperature
    temperature              => 180,  # Current heating element temp
    ambient                  => 25,   # Ambient temperature
    period                   => 1.5   # Time period
  };
  
  my $required_power = $predictor->predictPower($status);
  print "Required power: ${required_power}W\n";

=head2 Power Prediction with Anticipation

  # Predict power required for target temperature 3 periods ahead
  my $status = {
    'anticipate-temperature' => 190,  # Target temperature 6 seconds from now
    'anticipate-period'      => 6,    # Look ahead 6 seconds
    'predict-temperature'    => 177,  # Current hotplate temperature
    temperature              => 180,  # Current heating element temp
    ambient                  => 25,  # Ambient temperature
    period                   => 1.5   # Time period
  };
  
  my $required_power = $predictor->predictPower($status);
  print "Required power for 6 second anticipation: ${required_power}W\n";

=head2 Tuning Parameters

  # Tune parameters using historical data
  my $tuned_params = $predictor->tune($historical_samples);
  
  print "Tuned bands: " . scalar(@{$tuned_params->{bands}}) . "\n";
  foreach my $band (@{$tuned_params->{bands}}) {
    print "Band at ${band->{temperature}}°C: inner-tau=${band->{'inner-tau'}}, outer-tau=${band->{'outer-tau'}}\n";
  }

=head1 THERMAL MODEL DETAILS

The BandedLPF predictor models the thermal system as a cascaded first-order system with 
temperature-dependent parameters:

=over

=item * **Heating Element**: The primary heat source with measured temperature.

=item * **Inner Thermal Mass**: Modeled by temperature-dependent inner-tau, representing heat transfer from heating element to hotplate.

=item * **Hotplate**: The target whose temperature is being predicted.

=item * **Outer Thermal Mass**: Modeled by temperature-dependent outer-tau, representing heat loss to ambient environment.

=item * **Power Response**: Optional modeling of power-to-temperature response for feed-forward control.

=back

The model assumes:
- Piecewise linear variation of thermal properties with temperature
- Linear heat transfer relationships within each temperature band
- Smooth interpolation between temperature bands
- Negligible heat transfer directly from heating element to ambient

=head1 ADVANTAGES OVER OTHER MODELS

Compared to L<Milton::Predictor::LossyLPF> and L<Milton::Predictor::DoubleLPF>, this model provides:

=over

=item * More accurate modeling of non-linear thermal properties

=item * Temperature-dependent parameter variation

=item * Power prediction capabilities for feed-forward control

=item * Superior accuracy across wide temperature ranges

=item * Automatic band generation during tuning

=back

=head1 LIMITATIONS

=over

=item * Requires more training data for proper band generation

=item * More complex tuning process

=item * Higher computational overhead due to piecewise linear interpolation

=item * Requires current ambient temperature measurement

=back

=head1 SEE ALSO

=over

=item * L<Milton::Predictor> - Base predictor class

=item * L<Milton::Predictor::LossyLPF> - Simpler single-filter model

=item * L<Milton::Predictor::DoubleLPF> - Dual-filter model with constant parameters

=item * L<Milton::Math::PiecewiseLinear> - Piecewise linear interpolation utilities

=item * L<Milton::Math::Util> - Mathematical utilities used for tuning

=item * L<Milton::Controller> - Controller classes that use this predictor

=back

=head1 AUTHOR

Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  if (!exists $self->{bands}) {
    $self->{bands} = [ { temperature => 25 , 'inner-tau' => 3.357 , 'outer-tau' => 2000 } ];
  }
  $self->{'inner-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'inner-tau', @{$self->{bands}});
  $self->{'outer-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'outer-tau', @{$self->{bands}});
  $self->{'power-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'power-tau', @{$self->{bands}});
  $self->{'power-gain'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'power-gain', @{$self->{bands}});

  if ($self->{'power-tau'}->length < 1) {
    delete $self->{'power-tau'};
  }
  if ($self->{'power-gain'}->length < 1) {
    delete $self->{'power-gain'};
  }

  return $self;
}

sub description {
  my ($self) = @_;

  if (!exists $self->{description}) {
    my ($itmin, $itmax);
    my ($otmin, $otmax);
    my ($ptmin, $ptmax);
    my ($pgmin, $pgmax);

    foreach my $band (@{$self->{bands}}) {
      $itmin = $band->{'inner-tau'} if !defined $itmin || $band->{'inner-tau'} < $itmin;
      $itmax = $band->{'inner-tau'} if !defined $itmax || $band->{'inner-tau'} > $itmax;
      $otmin = $band->{'outer-tau'} if !defined $otmin || $band->{'outer-tau'} < $otmin;
      $otmax = $band->{'outer-tau'} if !defined $otmax || $band->{'outer-tau'} > $otmax;
      $ptmin = $band->{'power-tau'} if !defined $ptmin || $band->{'power-tau'} < $ptmin;
      $ptmax = $band->{'power-tau'} if !defined $ptmax || $band->{'power-tau'} > $ptmax;
      $pgmin = $band->{'power-gain'} if !defined $pgmin || $band->{'power-gain'} < $pgmin;
      $pgmax = $band->{'power-gain'} if !defined $pgmax || $band->{'power-gain'} > $pgmax;
    }

    $self->{description} = sprintf('BandedLPF (inner-tau: [%.3f-%.3f], outer-tau: [%.3f-%.3f], power-tau: [%.3f-%.3f], power-gain: [%.3f-%.3f])'
                                 , $itmin, $itmax, $otmin, $otmax, $ptmin, $ptmax, $pgmin, $pgmax
                                 );
  }

  return $self->{description};
}

sub setInterface {
  my ($self, $interface) = @_;
  $self->{interface} = $interface;
}

sub _predictHeatingElement {
  my ($self, $status, $last_heating_element) = @_;

  my $period = $status->{period};
  my $power = $status->{power};
  my $ambient = $status->{ambient};
  my $temperature = $last_heating_element;
  my $reference_temperature = $temperature // $ambient;
  my $prediction;

  if (defined $temperature) {
    my $gain = $self->{'power-gain'}->estimate($reference_temperature);
    my $ss_temp = $ambient + $power * $gain;

    my $tau = $self->{'power-tau'}->estimate($reference_temperature);
    my $alpha = $period / ($period + $tau);

    $prediction = $temperature * (1-$alpha) + $alpha * $ss_temp;
  } else {
    $prediction = $status->{temperature} // $ambient;
  }

  return $prediction;
}

sub predictHeatingElement {
  my ($self, $status) = @_;

  if (!exists($self->{'power-tau'}) || !exists($self->{'power-gain'})) {
    return;
  }

  my $prediction = $self->_predictHeatingElement($status, $self->{'last-heating-element'});
  $self->{'last-heating-element'} = $prediction;
  $status->{'predict-heating-element'} = $prediction;

  if (!defined $status->{temperature}) {
    $status->{temperature} = $prediction;
  } elsif (!exists $status->{'device-temperature'}) {
    $status->{'device-temperature'} = $prediction;
  }

  return $prediction;
}

sub _calculateTemperatureForPower {
  my ($self, $status, $power, $last_prediction, $last_heating_element) = @_;

  delete $status->{temperature};
  $status->{power} = $power;

  $status->{temperature} = $self->_predictHeatingElement($status, $last_heating_element);
  return $self->_predictTemperature($status, $last_prediction);
}

sub predictPower {
  my ($self, $status) = @_;

  if (!exists($self->{'power-tau'}) || !exists($self->{'power-gain'})) {
    return 0;
  }

  # Set up state for predicting temperature for a given power level
  my $target_temp = $status->{'anticipate-temperature'} // $status->{'then-temperature'};
  if (!defined $target_temp) {
    return;
  }

  my $last_prediction = $status->{'predict-temperature'};
  my $last_heating_element = $status->{'temperature'};
  my $next_status = { ambient => $status->{ambient}
                    , period => $status->{'anticipate-period'} // $status->{period}
                    };

  # Start with a high guess and a low guess
  my ($plo, $phi) = $self->{interface}->getPowerLimits();
  my $thi = $self->_calculateTemperatureForPower($next_status, $phi, $last_prediction, $last_heating_element);

  # If maximum power isn't going to get us up there, then we're done
  if ($thi < $target_temp) {
    return $phi;
  }

  my $tlo = $self->_calculateTemperatureForPower($next_status, $plo, $last_prediction, $last_heating_element);
  # If minimum power isn't going to get us down there, then we're done
  if ($tlo > $target_temp) {
    return $plo;
  }

  # Otherwise, we need to binary search between the two
  while ($phi - $plo > 1) {
    my $p = ($plo + $phi) / 2;
    my $t = $self->_calculateTemperatureForPower($next_status, $p, $last_prediction, $last_heating_element);

    if ($t < $target_temp) {
      $plo = $p;
      $tlo = $t;
    } elsif ($t == $target_temp) {
      return $p;
    } else  {
      $phi = $p;
      $thi = $t;
    }
  }

  # Linear interpolate between the two
  return $plo + ($phi - $plo) * ($target_temp - $tlo) / ($thi - $tlo);
}

# Return period unless the elapsed time is significantly different.
sub _period {
  my ($self, $status) = @_;
  my $period = $status->{period};
  my $elapsed = $status->{elapsed};

  if (defined $elapsed) {
    if (abs($elapsed / $period - 1) > 0.02) {
      $self->debug('Period mismatch: elapsed=%03f, period=%03f', $elapsed, $period) if DEBUG_LEVEL >= DEBUG_DATA;
      return $elapsed;
    }
  }

  return $period;
}

sub _predictTemperature {
  my ($self, $status, $last_prediction) = @_;

  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $period = $self->_period($status);

    # Pull hotplate temperature towards heating element temperature
    my $inner_tau = $self->{'inner-tau'}->estimate($last_prediction);
    my $alpha = $period / ($period + $inner_tau);
    my $intermediate_temp = $status->{temperature} * $alpha + (1-$alpha) * $last_prediction;

    # And pull it back down to ambient temperature
    my $tau = $self->{'outer-tau'}->estimate($intermediate_temp);
    $alpha = $period / ($period + $tau);
    $prediction = $ambient * $alpha + (1-$alpha) * $intermediate_temp;
  } else {
    $prediction = $status->{temperature};
  }

  return $prediction;
}

sub predictTemperature {
  my ($self, $status) = @_;

  if ($self->{tuning}) {
    $self->predictHeatingElement($status);
  }

  my $prediction = $self->_predictTemperature($status, $self->{'last-prediction'});

  $self->{'last-prediction'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-prediction'};

  foreach my $key (qw(inner-tau outer-tau power-tau power-gain)) {
    if (!ref $self->{$key}) {
      $self->{$key} = Milton::Math::PiecewiseLinear->new->addPoint(25, $self->{$key});
    }
  }
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $parallel = $self->{tuning}->{parallel} // 1;

  my $bands = $self->buildSampleBands($samples);
  my $tuned = [];
  $self->{tuning} = 1;

  foreach my $band (@$bands) {
    $self->info("Band Centre: $band->{centre}, sample count: ". scalar(@{$band->{samples}}));

    my $t = $self->_tune($band->{samples}
                       , [ 'inner-tau', 'outer-tau' ]
                       , [ [ 0, 30 ], [ 100, 4000 ] ]
                       , 'lower-constraint' => [ 0, 0 ]
                       , threshold => [ 0.001, 0.001 ]
                       , steps => [ 80, 80 ]
                       , bias => 1
                       , depth => 150
                       , %args
                       );
    my $p = $self->_tune($band->{samples}
                       , [ 'power-tau', 'power-gain' ]
                       , [ [ 0.1, 200 ], [ 0.1, 20 ] ]
                       , 'lower-constraint' => [ 0.1, 0.1 ]
                       , threshold => [ 0.001, 0.001 ]
                       , steps => [ 80, 80 ]
                       , bias => 1
                       , depth => 150
                       , prediction => 'predict-heating-element'
                       , expected => 'temperature'
                       , %args
                       );

    # Don't need package name here
    delete $t->{package};
    delete $p->{package};
    my $temperature = $band->{centre} // (($band->{min} + $band->{max})/2);

    push @$tuned, { temperature => $temperature
                  , %$t
                  , %$p
                  };
  }

  delete $self->{tuning};

  # Flatten out the bottom end
  my $t = { %{$tuned->[0]} };
  $t->{temperature} = 25;
  unshift @$tuned, $t;

  # Flatten out the top end
  $t = { %{$tuned->[-1]} };
  $t->{temperature} = 250;
  push @$tuned, $t;
  
  return { package => ref($self), bands => $tuned };
}

1;