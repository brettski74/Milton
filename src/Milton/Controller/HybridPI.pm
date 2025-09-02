package Milton::Controller::HybridPI;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);

use base 'Milton::Controller::RTDController';

use Milton::Predictor::DoubleLPFPower;
use Milton::ValueTools qw(writeCSVData);

use Milton::Math::Util qw(sgn minimumSearch);

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  $self->{gains}->{kp} //= 2.47;
  $self->{gains}->{ki} //= 0.1;
  $self->{gains}->{kaw} //= $self->{gains}->{ki} / ($self->{gains}->{kp} || 1);

  # No low-pass filtering on the control signal by default.
  $self->{'control-tau'} //= 0;
  $self->{'feed-forward-tau'} //= 0;

  # By default, use the full feed-forward signal.
  $self->{'feed-forward-gain'} //= 1;

  # Only designed to work with the DoubleLPFPower predictor.
  if (!defined $self->{predictor}) {
    $self->{predictor} = Milton::Predictor::DoubleLPFPower->new;
  } elsif ($self->{'feed-forward-gain'} > 0 && ! $self->{predictor}->can('predictPower')) {
    croak 'Feed-forward control requires a predictor that supports the predictPower method. '. ref($self->{predictor}) .' does not. Either set feed-forward-gain to 0 or use a different predictor or controller.';
  }

  return $self;
}

sub description {
  my ($self) = @_;

  return sprintf('HybridPI (ff-gain: %.3f, ff-tau: %.3f, kp: %.3f, ki: %.3f, control-tau: %.3f)'
               , $self->{'feed-forward-gain'}
               , $self->{'feed-forward-tau'}
               , $self->{gains}->{kp}
               , $self->{gains}->{ki}
               , $self->{'control-tau'}
               );
}

sub getRequiredPower {
  my ($self, $status) = @_;

  my $period = $status->{period};
  $status->{'predict-temperature'} = $self->{predictor}->predictTemperature($status);

  my $ff_power = 0;
  my $ff_gain = $self->{'feed-forward-gain'};
  if ($ff_gain > 0) {
    $ff_power = $self->{predictor}->predictPower($status) * $self->{'feed-forward-gain'};

    my $ff_tau = $self->{'feed-forward-tau'};
    if ($ff_tau > 0) {
      if (exists $self->{'last-ff-power'}) {
        my $ff_alpha = $period / ($period + $ff_tau);
        $ff_power = $ff_power * $ff_alpha + (1 - $ff_alpha) * $self->{'last-ff-power'};
      }
      $self->{'last-ff-power'} = $ff_power;
    }
  }

  my ($pmin, $pmax) = $self->{interface}->getPowerLimits();

  my $ki = $self->{gains}->{ki};
  my $kp = $self->{gains}->{kp};
  my $kaw = $self->{gains}->{kaw};

  # Note that predict-temperature is the temperature we're trying to control and now-temperature is the
  # expected temperature for *now* as per the reflow profile.
  my $error = $status->{'then-temperature'} - $status->{'predict-temperature'};

  my $integral = $self->{integral} //= 0;
  my $iterm = $error * $ki * $period;
  $integral += $iterm;
  $status->{integral} = $integral;
  $status->{iterm} = $iterm;
  $status->{'ff-power'} = $ff_power;

  my $power_unsat = $ff_power + $kp * $error + $integral;
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
  $integral += $kaw * ($power_sat - $power_unsat);

  # Clamp the integral if we're still too big.
  my $anti_windup_clamp = $self->{'anti-windup-clamp'};
  my $imax = $anti_windup_clamp / 100 * $pmax;
  if ($integral > $imax) {
    $integral = $imax;
  } elsif ($integral < -$imax) {
    $integral = -$imax;
  }

  $self->{integral} = $integral;

  # Low-pass filter the control signal if required.
  my $control_tau = $self->{'control-tau'};
  my $power = $power_sat;
  if ($control_tau > 0) {
    if (exists $self->{'last-power'}) {
      my $control_alpha = $period / ($period + $control_tau);
      $power = $power_sat * $control_alpha + (1 - $control_alpha) * $self->{'last-power'};
    }
    $self->{'last-power'} = $power;
  }

  return $power;
}

sub initialize {
  my ($self) = @_;
  $self->{integral} = 0;

  if (defined $self->{tau_i}) {
    $self->{ki} = $self->{kp} / $self->{tau_i};
    $self->{kaw} = $self->{ki} / $self->{kp};
    delete $self->{tau_i};
  }
}

sub _tune {
  my ($self, $samples, $params, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'now-temperature';

  my $time_cut_off = $self->{'time-cut-off'} // 180;
  my $temperature_cut_off = $self->{'temperature-cut-off'} // 120;

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    foreach my $param (@$params) {
      $self->{$param} = shift;
    }
    $self->initialize;

    my $sum2 = 0;
    my $power = 0;

    foreach my $sample (@$samples) {
      if (!exists($sample->{event}) || $sample->{event} eq 'timerEvent') {
        # Remove existing temperature so that predictor can calculate it.
        delete $sample->{temperature};
        
        # Set applied power based on last command for power.
        $sample->{'set-power'} = $power;
        $sample->{power} = $power;

        # Predict temperature
        $self->{predictor}->predictTemperature($sample, $power);

        # Profile temperatures should already be in there from the actual run!

        # Get the power for the next sample.
        $power = $self->getRequiredPower($sample);

        # Avoid using the long cool-down tail samples. We don't care about them and want the
        # prediction to best match the important/active sections of the profile.
        if ($sample->{now} < $time_cut_off || $sample->{$expected} > $temperature_cut_off) {
          my $error = $sample->{$prediction} - $sample->{$expected};
          my $err2 = $error * $error;

          if ($options{bias}) {
            $err2 = $err2 * ($sample->{$expected} - $sample->{ambient});
          }
          
          $sum2 += $err2;
        }
      }
    }

    return $sum2;
  };

  my @values = minimumSearch($fn, $bounds, %options);
  my $tuned = {};

  # Set the optimal parameter values in case we need to use them for anything else.
  foreach my $param (@$params) {
    my $val = shift @values;
    $self->{$param} = $val;
    $tuned->{$param} = $val;
  }
  $self->initialize;

  $tuned->{package} = ref($self);

  return $tuned;
}

sub tuningPass {
  my ($self, $kp, $tau_i, $period, $profile, $fn) = @_;
  $self->{gains}->{kp} = $kp;
  $self->{gains}->{ki} = $kp / $tau_i;
  $self->{gains}->{kaw} = $self->{gains}->{ki} / $kp;

  my $sum2 = 0;
  my $now = 0;
  my $end = $profile->end;
  my $ambient = 27;
  my $heating_element = $ambient;
  my $sample = { ambient => $ambient, period => $period };
  my $power = 0;
  my $hotplate = $heating_element;

  while ($now < $end) {
    $sample->{now} = $now;
    $sample->{then} = $now+$period;
    $sample->{'now-temperature'} = $profile->estimate($now);
    $sample->{'then-temperature'} = $profile->estimate($now+$period);
    $sample->{power} = $power;
    delete $sample->{temperature};
    delete $sample->{'predict-temperature'};
    delete $sample->{'predict-heating-element'};
    delete $sample->{integral};
    delete $sample->{iterm};
    delete $sample->{'ff-power'};

    $self->{predictor}->predictHeatingElement($sample, $heating_element);
    $self->{predictor}->predictTemperature($sample);
    $power = $self->getRequiredPower($sample);

    if (defined $fn) {
      $fn->($sample);
    }

    my $error = $sample->{'then-temperature'} - $sample->{'predict-temperature'};
    my $err2 = $error * $error;
    $sum2 += $err2;

    $now += $period;
  }

  return $sum2;
}

sub tune {
  my ($self, %options) = @_;

  # We don't need a history. Everything is simulated.
  my $period = $options{period} // 1.5;
  my $profile = $options{profile};

  # Tune kp and ki as if pure PI controller only.
  my $ff_gain_saved = $self->{'feed-forward-gain'};
  $self->{'feed-forward-gain'} = 0;

  my $fn = sub {
    return $self->tuningPass(@_, $period, $profile);
  };
  my ($kp, $tau_i) = minimumSearch($fn
                                 , [ [ 0.0001, 100 ], [ 0.0001, 1000 ] ]
                                 , depth => 150
                                 , threshold => [ 0.001, 0.0001 ]
                                 , 'lower-constraint' => [ 0.001, 0.001 ]
                                 , %options
                                 );

  my $ki = $kp / $tau_i;
  my $tuned = { kp => $kp
              , ki => $ki
              , kaw => 1 / $tau_i
              };

  # Restore the feed-forward gain.
  $self->{'feed-forward-gain'} = $ff_gain_saved;

  # Update the tuned parameters to reflect what we actually want to store.
  delete $self->{tau_i};

  return $tuned;
}

1;