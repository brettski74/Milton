package PowerSupplyControl::Command::calibrate;

use strict;
use warnings qw(all -uninitialized);


use base qw(PowerSupplyControl::Command);
use Scalar::Util qw(looks_like_number);
use Readonly;
use Carp;
use Time::HiRes qw(sleep);
use Hash::Merge;

Readonly my %ALLOYS => ( In97Ag3 => 143
                       , In52Sn48 => 118
                       , In663Bi337 => 72
                       , Sn63Pb37 => 183
                       , Sn965Ag35 => 221
                       , Sn62Pb36Ag2 => 179
                       , Bi58Sn42 => 138
                       , Sn993Cu07 => 227
                       , Indium => 157
                       , Tin => 232
                       );

=head1 NAME

PowerSupplyControl::Command::calibrate - Calibrate the hotplate

=head1 SYNOPSIS

  my $self = PowerSupplyControl::Command->new($config);

  return $self;
}

=head1 DESCRIPTION

Run a calibration cycle to determine the following details for the hotplate:

=over

=item Resistance to temperature mapping

In theory, we can determine the resistance of the hotplace at different temperatures based on the resistance measured at
one temperature and the applying the formula for resistance based on the temperature coefficient of the material -
presumably copper. In practice, a piecewise linear approximation seems to produce better results, so you can specify
several target temperatures that will have corresponding resistance recorded. During the calibration cycle, you will
need to hit the spacebar as each calibration temperature is reached. The resistance measured at that time will then be
recorded as the resistance corresponding to that temperature.

=item Thermal resistance to ambient

For feed-forward control, we need an operating thermal model of the hotplate. The model used has two parameters. The
first of those is the thermal resistance of the hotplate to the ambient environment. This relates the rate at which heat
is lost to the surrounding environment in proportion to the temperature difference between the hotplate and the ambient
temperature. This will be estimated by applying a constant power level to the hotplate and observing the steady state
temperature that the hoplate reaches from both below and above the steady state temperature.

=item Heat capacity

This is the second parameter needed for the thermal model. It specifies the amount of energy required to raise the
temperature of the hotplate by one degree Celsius/Kelvin. Once we have the thermal resistance, we can fit an exponential
curve to the time versus temperature data and calculate the heat capacity from the time constant of the system.

=back

=head2 Calibration Cycle

The calibration cycle will progress through the following stages:

=over

=item Warm Up

A constant power level is applied to the hotplate and the temperature difference between successive samples is monitored
and recorded. The temperature deltas are passed through an IIR low pass filter and when the filtered result falls below
a suitable threshold, the hotplate is assumed to be very close to the steady state temperature for the given power level.
Based on that, an initial estimate of the thermal resistance and heat capacity are calculated and used in the next stage
to effect control of the hotplate. Since we probably don't have a resistance to temperature mapping at this point, we use
an approximation based on the cold resistance of the hotplate and the temperature coefficient of copper.

=item Slow Temperature Ramp

Once a steady state temperature is reached in the previous stage, the hotplate is then heated at a constant slow rate
until the maximum calibration temperature is reached. At this point, we can build a complete resistance to temperature
mapping. The ramp continues for a small amount above the maximum calibration temperature as a certainty margin before
advancing to the next stage.

=item Short Hold

After the temperature ramp, the hotplate will be held at a constant temperature for a short time to ensure that the
final stage starts from a steady state and avoids any inaccuracies due to thermal inertia and offset effects.

=item Cool Down

The initial calibration power is re-applied to the hotplate and it is allowed to cool down back to a steady state. The
same steady state condition using an IIR low pass filter is used to determine steady state as in the warm up stage.

=back

Once all stages have been completed, the entire history of measurements are updated with accurate temperature values
via our complete resistance to temperature mapping. We then re-calculate the thermal model parameters using both the
warm up and cool down curves and average the results to produce a final set of parameters.

=head1 CONFIGURATION PARAMETERS

The following configuration parameters are understood by this command and should be specified in the commands->calibrate
section of the configuration file. Some of them can also be provided on the command line.

=over

=item temperatures

A list of temperatures to calibrate the hotplate for the resistance to temperature mapping. These can be specified as
either a temperature in degrees Celsius or a known alloy name. There are two suggested ways to calibrate the resistance
to temperature mapping.

=over

=item Digital Thermometer

If you have a digital thermometer of some sort you can use it to measure the temperature of the hotplate as it is heated
during the calibration cycle. This could be a kitchen thermometer or a thermocouple attached to a multimeter or any other
kind of device that can accurately record the temperature. Good thermal coupling to the hotplate is important to ensure
accurate and timelin temperature measurements. The use of kaptan tape or thermal paste may be helpful in ensuring this,
provided you're willing to get such materials onto your thermometer probe. Thermal paste may not be a great option if you
plan to use the thermometer in the kitchen afterwards!

=item Calibration Alloys

If you have several different solder alloys available, you can use them to calibrate the hotplate. Ideally, these should
be eutectic solder alloys so that they have a well defined melting point. You simply cut a short piece of solder wire of
each alloy - perhaps 3-4 mm long. You then place these near the centre of the hotplate and wait for them to melt. You want
pieces that are about 2-3 times as long as they are wide. When they melt, surface tension will cause them to form a sphere
almost instantly, which is easy to observe. If the wire is too short, the transition from cylinder to sphere may be had to
spot. Similarly, if the wire is too long, the transition to a more ball-shaped glob of liquid may be slower.

=back

=item hold-time

The time in seconds that the hotplate is held at the maximum temperature during the short hold stage of the calibration
cycle. This defaults to 15 seconds.

=item initial-current

The initial current applied to the hotplate during preprocessing to ensure that resistance can be measured in the first polling
once the main event loop starts. This defaults to 1.0 amps.

=item power

The calibration power applied to the hotplate during the constant power stages of the calibration cycle. If not explicitly
specified, it can be defaulted to a reasonable value based on an estimate of thermal resistance using the mechanical details
of your hotplate assembly and the calibration temperatures you plan to use. The goal is to aim for a steady state temperature
where the temperature rise above ambient is about 90% of the way to the first calibration temperature. In the absence of
mechanical details of the hotplate assembly, a thermal resistance of 2.4K/W will be assumed.

=item ramp-rate

The rate in Celsius/Kelvin per second at which the hotplate is heated during the slow temperature ramp. This defaults to
0.5K/s.

=item steady-state-smoothing

The smoothing factor for the IIR low pass filter used to determine steady state temperature. This defaults to 0.9. Must be a
value between 0 and 1. Values closer to one will result in a slower response to temperature changes and a longer period of
time for the calibration cycle to settle and move on to the next stage but will be more accurate in determining steady state.

=item steady-state-threshold

The threshold for the IIR low pass filter used to determine steady state temperature. Since we don't yet have an up-to-date
resistance to temperature mapping, steady state is determined by looking at resistance deltas as a proxy for temperature
deltas. Therefore, the threshold is essentially a resistance value and will be defaulted to 10% of the cold temperature
resistance of the hotplate.

=item steady-state-samples

The number of samples to use to determine steady state temperature. There must be at least 10 consecutive samples that meet
the steady state criteria before steady state is considered to have been reached. This defaults to 10.

=item steady-state-reset

The threshold above which we stop counting positive steady state samples. This defaults to 1.5 times the steady state
threshold.

=back

=head1 METHODS

=head2 defaults

Return a hash of default configuration values for this command.

=cut

sub defaults {
  return { 'initial-current' => 1.0
         , 'ramp-rate' => 0.3
         , 'steady-state-smoothing' => 0.9
         , 'steady-state-samples' => 10
         , 'steady-state-threshold' => 0.0001
         , 'hold-time' => 15
         , 'temperatures' => [ 100, 140, 180, 200 ]
         };
}

=head2 options

Return a hash of options for Getopt::Long parsing of the command line arguments.

=cut

sub options {
  return ( 'reset' );
}

=head2 initialize

Initialize the calibrate command.

=cut

sub initialize {
  my ($self) = @_;

  my $temps = $self->{temperatures};

  # Build the numeric temperatures list.
  foreach my $temp (@$temps) {
    if (looks_like_number($temp)) {
      push @$temps, $temp;
    } else {
      if (exists $ALLOYS{$temp}) {
        push @$temps, $ALLOYS{$temp};
      } else {
        croak "Unknown calibration temperature in configuration: $temp";
      }
    }
  }

  # Ensure that the temperatures are in ascending order.
  @$temps = sort { $a <=> $b } @$temps;
  $self->{'temperatures'} = $temps;

  return $self;
}

=head2 preprocess

Initialize the calibrate command.

This method is called during object creation.

=cut

sub preprocess {
  my ($self, $status) = @_;

  # Prompt for the current hotplate and ambient temperature, just to be sure.
  $self->{ambient} = $self->prompt('Ambient temperature', $self->{controller}->getAmbient || 20.0);
  $self->{controller}->setAmbient($self->{ambient});

  if (!$self->{keep}) {
    $self->{controller}->resetTemperatureCalibration;
  }

  $self->{'starting-temperature'} = $self->prompt('Current hotplate temperature', $self->{ambient});

  # Ensure that we have some power flowing into the hotplate so that resistance can be measured.
  $self->{interface}->setCurrent($self->{config}->{'initial-current'});
  # Pause for a bit to allow the power supply to settle.
  sleep(0.5);

  # Make sure that ambient temperature is part of our calibration set.
  my $sts = $self->{controller}->poll;
  my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
  %$status = $merge->merge($status, $sts);
  $status->{stage} = 'preprocess';
  $status->{temperature} = $self->{'starting-temperature'};
  $status->{resistance} = $status->{voltage} / $status->{current};
  $self->{controller}->setTemperaturePoint($status->{temperature}, $status->{resistance});
  print "Calibration point set: $status->{'temperature'} => $status->{'resistance'}\n";

  # Ensure that the starting temperature is part of our calibration set.
  my $first = $self->{temperatures}->[0];
  if (abs($first - $status->{temperature}) < 10) {
    # We're within 10 degrees of the first temperature, so just replace it with the actual temperature.
    $self->{temperatures}->[0] = $status->{temperature};
  } else {
    # Add in a new point at the beginning of the list.
    unshift @{$self->{temperatures}}, $status->{temperature};
  }
  $status->{'calibration-temperature'} = $status->{temperatures};
  $status->{'calibration-resistance'} = $status->{resistance};
  $self->{'calibration-points'} = [ $status ];

  # Now we can start the calibration cycle.
  $self->{stage} = 'warmUp';

  return $self;
}

=head2 timerEvent($status)

Handle a timer event.

=over

=item $status

A hash reference containing the current status of the hotplate.

=back

=cut

sub timerEvent {
  my ($self, $status) = @_;

  $status->{stage} = $self->{stage};
  my $stage = '_'. $self->{stage};

  return $self->$stage($status);
}

=head2 keyEvent($status)

Handle a key event.

=cut

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq ' ') {
    my $index = @{$self->{'calibration-points'}};
    $status->{'calibration-temperature'} = $self->{config}->{'temperatures'}->[$index];

    push @{$self->{'calibration-points'}}, $status;
    $self->beep;
    return $self;
  }
}

sub _checkSteadyState {
  my ($self, $status) = @_;

  return if !exists $status->{last} || !exists $status->{resistance};

  my $last = $status->{last};

  # If we don't have resistance readings, then we can't determine steady state.
  return if !exists $last->{resistance};

  my $smoothing = $self->{config}->{'steady-state-smoothing'};
  my $threshold = $self->{config}->{'steady-state-threshold'};
  my $samples = $self->{config}->{'steady-state-samples'};
  my $reset = $self->{config}->{'steady-state-reset'};

  my $deltaR = $status->{resistance} - $last->{resistance};
  $status->{'delta-R'} = $deltaR;
  
  # Apply to low pass filter
  if (exists $last->{'delta-R-filtered'}) {
    $status->{'delta-R-filtered'} = $smoothing * $last->{'delta-R-filtered'} + (1 - $smoothing) * $deltaR;
  } else {
    $status->{'delta-R-filtered'} = $deltaR;
  }

  if ($status->{'delta-R-filtered'} < $threshold) {
    $status->{'steady-state-count'}++;
  } elsif ($status->{'delta-R-filtered'} > $reset) {
    $status->{'steady-state-count'} = 0;
  }

  return $status->{'steady-state'} = $status->{'steady-state-count'} >= $samples;
}

=head2 _warmUp($status)

Handle the warm up stage of the calibration cycle.

=cut

sub _warmUp {
  my ($self, $status) = @_;

  if ($self->_checkSteadyState($status)) {
    $self->{'ramp-start-time'} = $status->{now};
    $self->{'ramp-start-temp'} = $status->{temperature};

    # Ensure that we don't have a maximum temperature set, yet.
    delete $self->{'maximum-temperature'};

    return $self->_advanceStage('slowRamp', $status);
  }

  $self->{interface}->setPower($self->{config}->{'calibration-power'});

  return $self;
}

sub _advanceStage {
  my ($self, $stage, $status) = @_;

  $self->beep;
  $self->{stage} = $stage;
  return $self->$stage($status);
}

sub _slowRamp {
  my ($self, $status) = @_;

  if (exists $self->{'maximum-temperature'}) {
    if ($status->{temperature} >= $self->{'maximum-temperature'}) {
      $self->{'hold-end-time'} = $status->{now} + $self->{config}->{'hold-time'};
      return $self->_advanceStage('shortHold', $status);
    }
  } elsif (@{$self->{'calibration-points'}} >= @{$self->{config}->{'temperatures'}}) {
    $self->{'maximum-temperature'} = $status->{temperature} + 5;
  }

  my $rate = $self->{config}->{'ramp-rate'};
  my $nextTemp = $self->{'ramp-start-temp'} + $rate * ($status->{now} - $self->{'ramp-start-time'});

  $self->{controller}->setTemperature($nextTemp);

  return $self;
}

sub _shortHold {
  my ($self, $status) = @_;

  if ($status->{now} >= $self->{'hold-end-time'}) {
    return $self->_advanceStage('coolDown', $status);
  }

  $self->{controller}->setTemperature($self->{'maximum-temperature'});

  return $self;
}

sub _coolDown {
  my ($self, $status) = @_;

  if ($self->_checkSteadyState($status)) {
    return;
  }

  $self->{interface}->setPower($self->{config}->{'calibration-power'});

  return $self;
}

sub postProcess {
  my ($self, $status, $history) = @_;

  # Make sure the hotplate is off.
  $self->{interface}->off;

  $self->_calculateResistanceTemperatureMapping;
  $self->_preProcessHistory($history);
  $self->_calculateThermalResistance;
  $self->_calculateHeatCapacity;
  $self->_writeCalibrationData;

  return;
}

sub _preProcessHistory {
  my ($self, $history) = @_;

  my $rt_mapping = $self->{'resistance-temperature-mapping'};
  my $warmUp = [];
  my $coolDown = [];

  foreach my $sts (@$history) {
    if (exists $sts->{resistance}) {
      # Recalculate temperature based on out more accurate resistance to temperature mapping.
      $sts->{temperature} = $rt_mapping->estimate($sts->{resistance});
    }

    # Collect the warm up and cool down sections of the history.
    if ($sts->{stage} eq 'warmUp') {
      push @$warmUp, $sts;
    } elsif ($sts->{stage} eq 'coolDown') {
      push @$coolDown, $sts;
    }
  }

  $self->{'warm-up-history'} = $warmUp;
  $self->{'cool-down-history'} = $coolDown;

  return;
}

sub _verifyCalibrationPoints {
  my ($self) = @_;

  my $points = $self->{'calibration-points'};
  my $temps = $self->{'temperatures'};

  return;
}

sub _calculateResistanceTemperatureMapping {
  my ($self) = @_;

  my $pwl = $PowerSupplyControl::Math::PiecewiseLinear->new;
  my $points = $self->{'calibration-points'};
  my $mapping = PowerSupplyControl::Math::PiecewiseLinear->new;

  # Get the resistance at the point before and after the keypress and use linear interpolation to estimate the resistance at the keypress.
  foreach my $point (@$points) {
    if (!exists $point->{'calibration-resistance'}) {
      my $last = $point->{last};
      my $next = $last->{next};
      $pwl->addPoint($last->{now}, $last->{resistance});
      $pwl->addPoint($next->{now}, $next->{resistance});

      $point->{'calibration-resistance'} = $pwl->estimate($point->{time});
    }

    print "Calibration point now=$point->{now}, time=$point->{time}, resistance=$point->{'calibration-resistance'}, temperature=$point->{'calibration-temperature'}\n";

    $mapping->addPoint($point->{'calibration-resistance'}, $point->{'calibration-temperature'});
  }

  $self->{'resistance-temperature-mapping'} = $mapping;

  return;
}

sub _calculateThermalResistance {
  my ($self) = @_;

  my ($warmUpPower, $warmUpResistance) = $self->_averagePowerResistance($self->{'warm-up-history'});
  my $warmUpTemperature = $self->{'resistance-temperature-mapping'}->estimate($warmUpResistance);
  my $warmUpThermalResistance = ($warmUpTemperature - $self->{'ambient'}) / $warmUpPower;

  my ($coolDownPower, $coolDownResistance) = $self->_averagePowerResistance($self->{'cool-down-history'});
  my $coolDownTemperature = $self->{'resistance-temperature-mapping'}->estimate($coolDownResistance);
  my $coolDownThermalResistance = ($coolDownTemperature - $self->{'ambient'}) / $coolDownPower;

  my $thermalResistance = ($warmUpThermalResistance + $coolDownThermalResistance) / 2;

  $self->{'thermal-resistance'} = $thermalResistance;
  $self->{'thermal-resistance-error'} = ($warmUpPower - $coolDownPower) / ($warmUpResistance - $coolDownResistance) / 2;

  print "Thermal resistance: $thermalResistance, error: +/-$self->{'thermal-resistance-error'}\n";
  
  return;
}

# Calculate the average power and resistance over the steady state samples.
# This is used for estimating the thermal resistance of the hotplate assembly.
sub _averagePowerResistance {
  my ($self, $history) = @_;

  my $sumPower = 0;
  my $sumResistance = 0;
  my $countPower = 0;
  my $countResistance = 0;

  for (my $i = -$self->{config}->{'steady-state-samples'}; $i < 0; $i++) {
    if (exists $history->[$i]->{power}) {
      $sumPower += $history->[$i]->{power};
      $countPower++;
    }

    if (exists $history->[$i]->{resistance}) {
      $sumResistance += $history->[$i]->{resistance};
    }
  }

  return ($sumPower / $countPower, $sumResistance / $countResistance);
}

sub _calculateHeatCapacity {
  my ($self) = @_;

  my $est = PowerSupplyControl::Math::FirstOrderStepEstimator->new(resistance => $self->{'thermal-resistance'});
  my $warmUp = $est->fitCurve($self->{'warm-up-history'}, 'temp', 'now');
  my $coolDown = $est->fitCurve($self->{'cool-down-history'}, 'temp', 'now');

  $self->{'heat-capacity'} = ($warmUp->{capacitance} + $coolDown->{capacitance}) / 2;
  $self->{'heat-capacity-error'} = ($warmUp->{capacitance} - $coolDown->{capacitance}) / 2;

  print "Heat capacity: $self->{'heat-capacity'}, error: +/-$self->{'heat-capacity-error'}\n";

  return;
}

sub _writeCalibrationData {
  my ($self) = @_;

  my $file = $self->{config}->{'calibration-file'};
  if (-f $file) {
    rename $file, "$file.". $self->timestamp;
  }

  my $fh = IO::File->new($file, 'w') || croak "Failed to open $file for writing";

  $fh->print("ambient: $self->{'ambient'}\n");
  $fh->print("resistance: $self->{'thermal-resistance'}\n");
  $fh->print("resistance-error: $self->{'thermal-resistance-error'}\n");
  $fh->print("capacity: $self->{'heat-capacity'}\n");
  $fh->print("capacity-error: $self->{'heat-capacity-error'}\n");
  $fh->print("temperatures:\n");
  my $points = $self->{'resistance-temperature-mapping'}->getPoints;
  foreach my $point (@$points) {
    $fh->print("  $point->[0]: $point->[1]\n");
  }

  $fh->close;

  return;
} 

1;