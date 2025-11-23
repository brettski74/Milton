package Milton::Controller::HybridPI;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);

use base 'Milton::Controller::RTDController';

use Milton::Predictor::DoubleLPFPower;
use Milton::ValueTools qw(writeCSVData);

use Milton::Math::Util qw(sgn minimumSearch);

=encoding utf8

=head1 NAME

Milton::Controller::HybridPI - Hotplate controller with both PI and feed-forward control

=head1 SYNOPSIS

  use Milton::Controller::HybridPI;
  
  # Create controller with default PI gains
  my $controller = Milton::Controller::HybridPI->new($config, $interface);
  
  # Create controller with custom gains and feed-forward
  my $config = { gains => { kp => 2.5,
                          , ki => 15
                          }
               , 'feed-forward-gain' => 1
               , anticipation => 3
               };
  
  my $controller = Milton::Controller::HybridPI->new($config, $interface);

=head1 DESCRIPTION

C<Milton::Controller::HybridPI> implements a hybrid control strategy combining proportional-integral 
(PI) feedback control with optional feed-forward compensation. This controller provides superior 
performance compared to simple bang-bang control, with the ability to operate in pure PI mode, 
pure feed-forward mode, or any combination of both.

The controller is designed to work with predictors that support power prediction (primarily 
L<Milton::Predictor::BandedLPF>) to provide feed-forward compensation based on anticipated 
heating requirements.

=head1 CONTROL ALGORITHM

The hybrid controller combines three control components:

=over

=item * **Feed-Forward Component**: Predicts required power based on target temperature profile

=item * **Proportional Component**: Responds to current temperature error

=item * **Integral Component**: Eliminates steady-state error through integral action

=back

The total control output is:

    power = feed_forward_power + kp * error + integral_term

Where the integral term includes anti-windup protection and the feed-forward component can be 
filtered for stability.

=head2 Feed-Forward Control

Feed-forward control uses the predictor to anticipate power requirements based on the target 
temperature profile. This provides:

=over

=item * **Proactive Control**: Starts heating before temperature error occurs

=item * **Profile Following**: Better tracking of rapid temperature changes

=item * **Reduced Overshoot**: Smoother control during profile transitions

=back

=head2 PI Control

The PI controller provides feedback compensation for:

=over

=item * **Model Errors**: Corrections for predictor inaccuracies

=item * **Disturbances**: Response to unexpected temperature changes

=item * **Steady-State Accuracy**: Elimination of offset errors

=back

=head1 PARAMETERS

=head2 gains

PI controller gains configuration:

=over

=item C<kp>

Proportional gain (W/°C) - determines response to temperature error

=item C<ki>

Integral gain (W/°C/s) - determines steady-state error elimination rate

=item C<kaw>

Anti-windup gain (1/s) - mitigates integral windup during saturation

=back

=over

=item * Default

kp: 25, ki: 15, kaw: 0.6

=item * Typical Range

kp: 1-100, ki: 1-100, kaw:0.01-100

=back

=head2 feed-forward-gain

Feed-forward controller gain (0.0 to 1.0). Controls the contribution of feed-forward 
prediction to the total control output.

=over

=item * 0.0: Pure PI control (no feed-forward)

=item * 1.0: Full feed-forward compensation

=item * 0.5-1.0: Typical values for hybrid control

=back

=head2 anticipation

The number of additional samples to look ahead when predicting the required power. This is
only used for feed-forward control. It provides smoother output from the feed-forward controller
and reduces overshoot/undershoot. If your feed-forward controller oscillates a lot, adding a few
samples worth of anticipation will usually fix that and reduce overshoot/undershoot at gradient
discontinuities. It generally does a better job than using a low-pass filter.

=head2 anti-windup-clamp

Anti-windup integral clamping limit as percentage of maximum power.

=over

=item * Default: 30% of maximum power

=item * Range: 0-100% of maximum power

=back

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Creates a new HybridPI controller instance.

=over

=item C<$config>

Configuration hash containing:

=over

=item C<gains>

PI controller gains (kp, ki, kaw)

=item C<feed-forward-gain>

Feed-forward compensation gain (default: 1.0)

=item C<anti-windup-clamp>

Anti-windup integral limit percentage (default: 30)

=item Standard RTDController configuration parameters

=back

=item C<$interface>

Interface object for power supply communication

=back

=head1 METHODS

=head2 getRequiredPower($status)

Calculates the required power using hybrid PI control with optional feed-forward.

=over

=item C<$status>

Status hash containing:

=over

=item C<anticipate-temperature> or C<then-temperature>

Target temperature (°C). If available, C<anticipate-temperature> is used, otherwise falls back to using C<then-temperature>.

=item C<predict-temperature>

Current predicted temperature (°C)

=item C<anticipate-period> or C<period>

Control period (seconds). If available, C<anticipate-period> is used, otherwise falls back to using C<period>.

=back

=item Return Value

Required power level (W)

=item Side Effects

Updates integral term and internal state variables

=back

=head2 tune(%options)

Tunes PI controller gains using simulation-based optimization.

=over

=item C<%options>

Tuning options:

=over

=item C<period>

Control period for simulation (default: 1.5 seconds)

=item C<profile>

Temperature profile for tuning simulation

=item Additional optimization parameters

=back

=item Return Value

Hash containing tuned gains (kp, ki, kaw)

=item Side Effects

Updates controller gains to tuned values

=back

=head1 USAGE EXAMPLES

=head2 Pure PI Control

  # Disable feed-forward for pure PI control
  my $config = { gains => { kp => 2.5
                          , ki => 0.15
                          , kaw => 0.06
                          }
               , 'feed-forward-gain' => 0  # Disable feed-forward
               };
  
  my $controller = Milton::Controller::HybridPI->new($config, $interface);

=head2 Pure Feed-Forward Control

  # Disable PI for pure feed-forward control
  my $config = { gains => { kp => 0
                          , kaw => 0
                          , kaw => 0
                          }
               , 'feed-forward-gain' => 1.0  # Full feed-forward
               , anticipation => 3
               };
  
  my $controller = Milton::Controller::HybridPI->new($config, $interface);

=head2 Hybrid Control

  # Balanced hybrid control
  my $config = { gains => { kp => 20.0
                          , ki => 5
                          , kaw => 0.05
                          }
               , ki => 5
               , kaw => 0.05
               }
               , 'feed-forward-gain' => 1
               , anticipation => 3
               };
  
  my $controller = Milton::Controller::HybridPI->new($config, $interface);

=head2 Tuning PI Gains

  # Tune PI gains using simulation
  my $tuned_gains = $controller->tune(period => 1.5
                                     , kaw => 0.05
                                     , profile => $reflow_profile
                                     );
  
  print "Tuned kp: $tuned_gains->{kp}\n";
  print "Tuned ki: $tuned_gains->{ki}\n";

=head1 TUNING GUIDELINES

=head2 Feed-Forward Tuning

Feed-forward control depends entirely on the predictor quality. For best results:

=over

=item * Use L<Milton::Predictor::BandedLPF> for accurate power prediction

=item * Tune predictor parameters using historical reflow data

=item * Start with feed-forward-gain = 1, anticipation = 3

=item * Adjust based on control performance

=back

=head2 PI Gain Tuning

The current automatic tuning implementation has limitations. Recommended approach:

=over

=item * Start with default gains (kp=25, ki=15, kaw=0.6)

=item * Manually adjust based on observed performance

=item * PI gains are forgiving of sub-optimal values

=item * Focus on feed-forward tuning for best results

=back

=head2 Manual PI Tuning

=over

=item * **Proportional Gain (kp)**: Increase for faster response, decrease for stability

=item * **Integral Gain (ki)**: Increase to eliminate steady-state error, decrease to prevent overshoot

=item * **Anti-windup (kaw)**: Set to ki/kp for standard anti-windup

=back

=head1 ADVANTAGES

=over

=item * Superior control performance compared to bang-bang

=item * Flexible control modes (PI, feed-forward, or hybrid)

=item * Excellent profile following with feed-forward

=item * Robust operation with anti-windup protection

=item * Smooth control output and temperature response

=back

=head1 DISADVANTAGES

=over

=item * Requires predictor tuning for feed-forward operation

=item * More complex than bang-bang control

=item * PI tuning can be challenging

=item * Dependent on predictor accuracy

=back

=head1 PREDICTOR REQUIREMENTS

Feed-forward control requires a predictor that supports the C<predictPower> method:

=over

=item * **Recommended**: L<Milton::Predictor::BandedLPF> - Most accurate and well-tested

=item * **Not Recommended**: L<Milton::Predictor::DoubleLPFPower> - Incomplete implementation

=back

=head1 INHERITANCE

This class inherits from L<Milton::Controller::RTDController>, which provides:

=over

=item * Temperature measurement using heating element as RTD

=item * Resistance-temperature calibration support

=item * Safety limits and cutoff features

=item * Interface management

=back

=head1 SEE ALSO

=over

=item * L<Milton::Controller::RTDController> - Base class for RTD-based controllers

=item * L<Milton::Controller::BangBang> - Simple bang-bang control alternative

=item * L<Milton::Predictor::BandedLPF> - Recommended predictor for feed-forward control

=item * L<Milton::Math::Util> - Optimization utilities used in tuning

=back

=head1 AUTHOR

Milton Controller Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  $self->{gains}->{kp} //= 25;
  $self->{gains}->{ki} //= 15;
  $self->{gains}->{kaw} //= $self->{gains}->{ki} / ($self->{gains}->{kp} || 1);

  # By default, use the full feed-forward signal.
  $self->{'feed-forward-gain'} //= 1;

  $self->{'anti-windup-clamp'} //= 30;

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

  return sprintf('HybridPI (ff-gain: %.3f, kp: %.3f, ki: %.3f, kaw: %.3f, anticipation: %d)'
               , $self->{'feed-forward-gain'}
               , $self->{gains}->{kp}
               , $self->{gains}->{ki}
               , $self->{gains}->{kaw}
               , $self->{'anticipation'}
               );
}

sub getRequiredPower {
  my ($self, $status) = @_;

  my $target_temp = $status->{'then-temperature'};
  if (!defined $target_temp) {
    return $self->SUPER::getRequiredPower($status);
  }

  my $period = $status->{period};
  $status->{'predict-temperature'} = $self->{predictor}->predictTemperature($status);

  my $ff_power = 0;
  my $ff_gain = $self->{'feed-forward-gain'};
  if ($ff_gain > 0) {
    $ff_power = $self->{predictor}->predictPower($status) * $self->{'feed-forward-gain'};
  }
  if (!defined $ff_power) {
    return $status->{'set-power'} // $status->{power};
  }

  my ($pmin, $pmax) = $self->{interface}->getPowerLimits();

  my $ki = $self->{gains}->{ki};
  my $kp = $self->{gains}->{kp};
  my $kaw = $self->{gains}->{kaw};

  # Note that predict-temperature is the temperature we're trying to control and now-temperature is the
  # expected temperature for *now* as per the reflow profile.
  my $error = $target_temp - $status->{'predict-temperature'};

  my $integral = $self->{integral} //= 0;
  my $iterm = $error * $ki * $period;

  # Avoid integral in the first few seconds when the profile may be intentionally under ambient
  # Hacky, but whatever...
  if ($status->{now} < 7.5) {
    $iterm = 0;
  }

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
  #$integral += $kaw * ($power_sat - $power_unsat);

  # Clamp the integral if we're still too big.
  my $anti_windup_clamp = $self->{'anti-windup-clamp'};
  my $imax = $anti_windup_clamp / 100 * $pmax;
  if ($integral > $imax) {
    $integral = $imax;
  } elsif ($integral < -$imax) {
    $integral = -$imax;
  }

  $self->{integral} = $integral;

  return $power_sat;
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