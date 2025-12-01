package Milton::Command::rth;

use strict;
use warnings qw(all -uninitialized);
use List::Util qw(min);
use base qw(Milton::Command);

use Milton::Math::SimpleLinearRegression;

=head1 NAME

Milton::Command::rth - Run a thermal test cycle to estimate the thermal resistance to ambient of a test assembly.

=head1 SYNOPSIS

    use Milton::Command::rth;

    my $rth = Milton::Command::rth->new();

=head1 DESCRIPTION

The thermal test cycle will run a test cycle to estimate the thermal resistance to ambient of a test assembly. This
coule be a heat sink, a heat sink + fan combo, a water block, peltier device, etc. The only caveat is that the test
assembly should be able to be mounted on a flat surface.

The test cycle starts with a preheat stage that will heat the hotplate with the assembly mounted on it to a specified
temperature. This is usually slightly higher than the final test temperature in order to get all of the heat sink
material up to the test temperature or higher. It will be heated using the current control algorithm and parameters.
Once a fixed period of time has passed, it will move into the soak stage/s.

The soak stage/s attempt to hold the assembly at a constant test temperature. This may be done initially using the
current control algorithm, although once at least one stage has been completed at the test temperature, the assembly
will be heated using a constant power level. This is estimated using the power level and temperature samples from
the end of the previous stage. 

Constant power level estimation is done using two different methods. Firstly, the power and temperature samples from
the end of the previous stage are averaged. If we were actually at a steady state, this would be all that is required
and we could simply use those numbers and calculate the thermal resistance. However, we don't know if we're at a steady
state and probably are not at a steady state. We also don't know the thermal time constant of the assembly under test
yet. As an approximation, we do a simple linear regression on the power and temperature samples over time. We use that
line to estimate the power level and temperature that would be expected after another sample period if those linear
trends continue. We then assume that steady state is somewhere between this prediction and the averages calculated
earlier. We average the two estimates to get our predicted steady state power level and temperature. This can then be
used to adjust the power level for the next stage.

The command can be configured to run multiple soak stages to try to hone in on the correct steady state power level
for our test temperature. Each progresses the same as above.

The final stage if the measurement stage. This stage runs like the soak stages although may be configured to run for
a longer period of time to allow for more accurate settling of the system and measurements. At the end of the
measurement stage, the predicted steady state power level and temperature are used to calculate the thermal resistance
of the hotplate.  Note that this thermal resistance is for the assembly that includes the hotplate, whereas we usually
want the thermal resistance of the heat sink or assembly that we have mounted on top of the hotplate. This is where
prior calibration of the hotplate is used. We assume that the bottom of the assembly under test is flat and that the
hotplate - being a thin flat aluminium sheet - dissipates heat to the ambient environment in a similar manner to the
flat base of the heat sink or assembly under test. We also assume that heat is dissipated from the majority hotplate
evenly across the entire area, so we can estimate the heat dissipation from any exposed areas of the hotplate using
a simple area ratio of the exposed area to the total area of the hotplate and if we have the thermal resistance to 
ambient of the unloaded hotplate, we can estimate the thermal resistance of the exposed area and model the overall
thermal resistance of the total assembly as two thermal resistances in parallel - one for the assembly under test and
one for the exposed area of the hotplate. If there is no exposed area of the hotplate (ie. the base of the assembly
under test completely covers the hotplate), then the thermal resistance of the assembly under test is simply assumed
to the approximately the same as the thermal resistance of the total assembly, including the hotplate.

The command can also be run in calibration mode. In this mode, the hotplate is run through a test cycle unloaded, but
the contact dimensions provided are the dimensions of the hotplate itself. Calibration mode also accepts additional
parameters to set the test temperature and stage times for the test cycle. These will be saved in the configuration
for the rth command to be used in actual measurement cycles.

=head1 CONSTRUCTOR

=head2 new($config, $interface, $controller, @args)

Create a new RTH command object.

=cut

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $config->{'test-delta-T'} //= 50;
  $config->{'preheat-time'} //= 90;
  $config->{'soak-time'} //= 150;
  $config->{'soak-count'} //= 3;
  $config->{'measure-time'} //= 240;
  $config->{'sample-time'} //= 60;
  $config->{'length'} //= 100;
  $config->{'width'} //= 100;
  $config->{'standard-mass'} //= 185;

  if ($self->{filename}) {
    $self->{calibration} = $self->{filename};
  }

  # Set up parameters, depends on whether we're in calibration or measurement mode
  if (! $self->{calibration}) {
    # Delete any parameters that cannot be set during measurement mode
    foreach my $key (qw(test-delta-T preheat-time soak-time soak-count measure-time sample-time)) {
      delete $self->{$key};
    }
  }

  # Delete any keys that should not exist in a new command object - ie. operational state variables
  foreach my $key (qw(samples mean-power mean-temperature test-temperature)) {
    delete $self->{$key};
  }

  foreach my $key (qw(test-delta-T preheat-time preheat-temp soak-time soak-count measure-time sample-time length width)) {
    if (!exists $self->{$key}) {
      $self->{$key} = $config->{$key};
    }
  }

  # For heavier heat-sinks, allow more time for settling.
  if ($self->{mass} > 0 && $config->{'standard-mass'} > 0) {
    my $mass_ratio = $self->{mass} / $config->{'standard-mass'};
    if ($mass_ratio > 1) {
      $self->{'preheat-time'} = $self->{'preheat-time'} * $mass_ratio;
      $self->{'soak-time'} = $self->{'soak-time'} * $mass_ratio;
      $self->{'measure-time'} = $self->{'measure-time'} * $mass_ratio;
    }
  }

  if ($config->{'soak-count'} > 0) {
    my $stages = [ 'preheat' ];
    for (my $i = 1; $i <= $config->{'soak-count'}; $i++) {
      push @$stages, "soak-$i";
    }
    push @$stages, 'measure';
    $self->{'stages'} = $stages;
  } else {
    $self->{'stages'} = [ qw(preheat soak measure) ];
  }

  return $self;
}

sub options {
  return ( 'length=i'
         , 'width=i'
         , 'test-delta-T=i'
         , 'preheat-time=i'
         , 'preheat-temp=i'
         , 'soak-time=i'
         , 'soak-count=i'
         , 'measure-time=i'
         , 'sample-time=i'
         , 'mass=f'
         , 'calibration'
         , 'filename=s'
         );
}

=head2 averageSamples($samples)

Given a set of recent samples of hotplate status, calculate the average power applied to the hotplate and the
surface temperature.

=over

=item $samples

A reference to a list of hash references containing the hotplate status samples. These will be status hashes
collected during each timer event during the sample period. The following keys are expected to be present in
each hash:

=over

=item power

The power applied to the hotplate in watts.

=item predict-temperature

The predicted temperature of the hotplate in degrees Celsius. This is only present if the predictor is enabled
but if present is the temperature value that will be preferentially used.

=item temperature

The actual temperature of the hotplate in degrees Celsius. This is only used as a fallback if the predict-temperature
key is not present.

=back

=item Return Value

A 2-element list containing the average power and temperature.

=back

=cut

sub averageSamples {
  my ($self, $samples) = @_;

  return if !@$samples;

  my $mean_power = 0;
  my $mean_temperature = 0;

  foreach my $sample (@$samples) {
    $mean_power += $sample->{'power'};
    $mean_temperature += (exists $sample->{'predict-temperature'} ? $sample->{'predict-temperature'} : $sample->{'temperature'});
  }

  $mean_power /= scalar(@$samples);
  $mean_temperature /= scalar(@$samples);

  $self->info("Rth Mean power: $mean_power");
  $self->info("Rth Mean temperature: $mean_temperature");

  return ($mean_power, $mean_temperature);
}

=head2 regressSamples($samples)

Using a set of samples, perform simple linear regression on the power and temperature data over time and use
the resulting regression lines to predict the power and temperature that would be expected at a future time if
those trends continue.

=over

=item $samples

A reference to a list of hash references containing the hotplate status samples. These will be status hashes
collected during each timer event during the sample period. The following keys are expected to be present in
each hash:

=over

=item now

The time that the sample was taken in seconds relative to the start of the cycle.

=item power

The power applied to the hotplate in watts.

=item predict-temperature

The predicted temperature of the hotplate in degrees Celsius. This is only present if the predictor is enabled
but if present is the temperature value that will be preferentially used.

=item temperature

The actual temperature of the hotplate in degrees Celsius. This is only used as a fallback if the predict-temperature
key is not present.

=back

=item Return Value

A 2-element list containing the linear-regression-predicted power and temperature. The prediction will be made one
sample period after the maximum timestamp (ie. now) seen in the samples.

=back

=cut

sub regressSamples {
  my ($self, $samples) = @_;

  return if !@$samples;

  my $regress_temp = Milton::Math::SimpleLinearRegression->new;
  my $regress_power = Milton::Math::SimpleLinearRegression->new;

  $regress_temp->addHashData('now', 'predict-temperature', @$samples);
  $regress_power->addHashData('now', 'power', @$samples);

  my $regress_time = $samples->[$#$samples]->{now} + $self->{'sample-time'};

  my $rpower = $regress_power->predict($regress_time);
  my $rtemp = $regress_temp->predict($regress_time);

  $self->info("Rth Regress power: $rpower");
  $self->info("Rth Regress temperature: $rtemp");

  return ($rpower, $rtemp);
}

sub preprocess {
  my ($self, $status) = @_;
  my $config = $self->{config};

  $self->startupCurrent($status);

  $self->info("Rth Stages: ". join(', ', @{$self->{'stages'}}));
  $self->{'test-temperature'} = $status->{ambient} + $self->{'test-delta-T'};

  $self->info("Rth Ambient temperature: $status->{ambient}");
  $self->info("Rth Test temperature: $self->{'test-temperature'}");

  foreach my $key (qw(test-delta-T preheat-time soak-time measure-time sample-time length width)) {
    $self->info("$key: $self->{$key}");
  }

  $self->info("Hotplate length: $config->{'length'}");
  $self->info("Hotplate width: $config->{'width'}");
  $self->info("Hotplate R_th: $config->{'hotplate-rth'}");

  $self->newStage($status);

  return $status;
}

=head2 predictSteadyState($status)

Predict the steady state power and temperature of the hotplate.

=over

=item $status

A reference to a hash containing the hotplate status.

=back

=item Return Value

A 2-element list containing the predicted power and temperature.

=back

=cut

sub predictSteadyState {
  my ($self, $status) = @_;

  ($self->{'mean-power'}, $self->{'mean-temperature'}) = $self->averageSamples($self->{samples});
  ($self->{'regress-power'}, $self->{'regress-temperature'}) = $self->regressSamples($self->{samples});
  $self->{'predict-power'} = ($self->{'regress-power'} + $self->{'mean-power'}) / 2;
  $self->{'predict-temperature'} = ($self->{'regress-temperature'} + $self->{'mean-temperature'}) / 2;

  $self->{ambient} = $status->{ambient};
    
  $self->info("Rth Predict power: $self->{'predict-power'}");
  $self->info("Rth Predict temperature: $self->{'predict-temperature'}");

  return ($self->{'predict-power'}, $self->{'predict-temperature'});
}

=head2 newStage($status)

Advance processing to the next stage of the test cycle.

=over

=item $status

A reference to a hash containing the hotplate status.

=back

=cut

sub newStage {
  my ($self, $status) = @_;

  $self->info("samples length: ". (defined($self->{samples}) ? scalar(@{$self->{samples}}) : 0));

  if ($self->{samples} && @{$self->{samples}} ) {
    $self->predictSteadyState($status);

    $self->info("Rth Ambient temperature: $status->{ambient}");
    $self->info("Rth Target temperature: ". ($self->{'test-delta-T'} + $status->{ambient}));
    my $rel_temp = $self->{'predict-temperature'} - $status->{ambient};
    $self->{'set-power'} = $self->{'predict-power'} * $self->{'test-delta-T'} / $rel_temp;
    $self->info("Rth Set power: $self->{'set-power'}");
  }

  my $stage = shift @{$self->{stages}};
  $self->{stage} = $stage;

  $stage =~ s/[^a-zA-Z]+$//;
  my $timeKey = "$stage-time";
  $self->info("Rth Stage time key: $timeKey");
  $self->info("Rth Stage time: $self->{$timeKey}");
  $self->{'stage-end'} = $self->{'stage-end'} + $self->{$timeKey};
  $self->{'sample-start'} = $self->{'stage-end'} - $self->{'sample-time'};

  $self->info("Rth Sample start: $self->{'sample-start'}");
  $self->info("Rth Stage end: $self->{'stage-end'}");
  $self->info("Rth Stage: $self->{stage}");

  if (defined $self->{"$stage-temp"}) {
    delete $self->{'mean-power'};
    delete $self->{'mean-temperature'};
    delete $self->{'set-power'};
    delete $self->{samples};
    $self->{'sample-start'} = 99999999;
  } else {
    $self->{samples} = [];
  }
}

sub timerEvent {
  my ($self, $status) = @_;
  my $now = $status->{now};

  if ($now > $self->{'stage-end'}) {
    $self->newStage($status);
    if ($now > $self->{'stage-end'}) {
      # We've hit the end of the cycle!
      return;
    }
  }

  my $stage = $self->{stage};
  $status->{stage} = $stage;

  if ($status->{now} > $self->{'sample-start'}) {
    push(@{$self->{samples}}, $status);
  }

  my $temperature = $self->{'test-temperature'};
  my $stageTempKey = "$stage-temp";
  if (defined $self->{$stageTempKey}) {
    $temperature = $self->{$stageTempKey} + $status->{ambient};
  }

  # Anticipation!
  my $anticipation = $self->{controller}->getAnticipation;
  if ($anticipation) {
    my $ant_period = ($anticipation + 1) * $status->{period};
    $status->{'anticipate-temperature'} = $temperature;
    $status->{'anticipate-period'} = $ant_period;
  }

  $status->{'then-temperature'} = $temperature;
  $status->{'now-temperature'} = $temperature;

  if (exists $self->{'set-power'}) {
    # $self->info("Constant Power: $self->{'set-power'}");
    # Calling this because it's the only way to get the temperature measurement and prediction done right now!
    $self->{controller}->getRequiredPower($status);

    # Ignore that and just set the power level we've calculated.
    $status->{'set-power'} = $self->{'set-power'};
  } else {
    my $power = $self->{controller}->getPowerLimited($status);
    $status->{'set-power'} = $power;
  }

  $self->{interface}->setPower($status->{'set-power'});

  return $status;
}

sub postprocess {
  my ($self, $status, $history) = @_;

  $self->info("Rth Ambient temperature: $status->{ambient}");
  $self->info("Power: $self->{'predict-power'}");
  $self->info("Temperature: $self->{'predict-temperature'}");

  my $total_rth = ($self->{'predict-temperature'} - $self->{ambient}) / $self->{'predict-power'};
  $self->info("Total R_th: $total_rth");

  if ($self->{calibration}) {
    $self->_writeCalibration($total_rth);
  } else {
    $self->_measureRth($total_rth);
  }

  return $status;
}

sub _writeCalibration {
  my ($self, $total_rth) = @_;
  my $filename = $self->{calibration};

  # If the calibration is set like a boolean flag, then use the default filename
  if ($filename == 1) {
    $filename = 'command/rth.yaml';
  }

  if ($filename !~ /\.yaml$/) {
    $filename .= '.yaml';
  }

  # If not an absolute path, then make it relative to $HOME/.config/milton
  if ($filename !~ /^\//) {
    $filename = "$ENV{HOME}/.config/milton/$filename";
  }

  my $fh = $self->replaceFile($filename);
  $fh->print("test-delta-T: $self->{'test-delta-T'}\n");
  $fh->print("preheat-time: $self->{'preheat-time'}\n");
  $fh->print("soak-time: $self->{'soak-time'}\n");

  if ($self->{'soak-count'} > 0) {
    $fh->print("soak-count: $self->{'soak-count'}\n");
  }

  $fh->print("measure-time: $self->{'measure-time'}\n");
  $fh->print("sample-time: $self->{'sample-time'}\n");
  $fh->print("length: $self->{'length'}\n");
  $fh->print("width: $self->{'width'}\n");
  $fh->print("hotplate-rth: $total_rth\n");
  $fh->close;
}

=head2 _measureRth($total_rth)

Measure the thermal resistance of the assembly under test.

The assumption here is that thermal conduction of heat away from the assembly is happening through
the hotplate and the assembly under test. Because the hotplate is in contact with the assembly under
test, the hotplate cannot leak heat into the ambient environment through its top surface where it
is in contact with the assembly under test. Similarly, the assembly under test cannot lead heat into
the ambient environment through its bottom surface where it is in contact with the hotplate, however
since the hotplate is a thin flat sheet of highly conductive material, it will lose heat to the
ambient environment through its bottom surface in roughly the same way that the assembly under
test would do. Therefore, any contact area between the hotplate and the assembly under test is
assumed to behave similarly to how the assembly under test would do in the absence of the hotplate.
Any portion of the hotplate which is not covered by the assembly under test will leak heat into the
ambient environment in a manner similar to how the hotplate does when it is unloaded. Therefore, the
thermal circuit can be approximated as two thermal conduction paths in parallel. One path has the
resistance of teh assembly under test. The other path has thermal conduction that is proportional to
the area of the hotplate that is not covered by the assembly under test. Since thermal resistance is
the inverse of thermal conductance, we can deduce the thermal resistance of the uncovered portion of
the hotplate based on the inverse ratio of uncovered area to total area of the hotplate and use the
thermal resistance of the unloaded hotplate that was calculated during calibration. Once we have this,
we just have to solve for the thermal resistance that can be placed in parallel with this to produce
the measured total thermal resistance of the assembly under test plus the hotplate.

=cut

sub _measureRth {
  my ($self, $total_rth) = @_;
  my $config = $self->{config};

  my $covered_length = min($self->{length}, $config->{length});
  my $covered_width = min($self->{width}, $config->{width});
  my $covered_area = $covered_length * $covered_width;

  my $hotplate_area = $config->{length} * $config->{width};

  my $uncovered_area = $hotplate_area - $covered_area;
  if ($uncovered_area <= 0) {
    $self->info("Uncovered R_th ratio: inf");
    $self->info("Uncovered Hotplate R_th: inf");
    $self->info("Assembly R_th: $total_rth");
    return $total_rth;
  }

  my $hotplate_ratio = $hotplate_area / $uncovered_area;
  my $hotplate_rth = $hotplate_ratio * $config->{'hotplate-rth'};

  $self->info("Uncovered R_th ratio: $hotplate_ratio");
  $self->info("Uncovered Hotplate R_th: $hotplate_rth");

  my $assembly_rth = $total_rth * $hotplate_rth / ($hotplate_rth - $total_rth);
  $self->info("Assembly R_th: $assembly_rth");

  return $assembly_rth;
}

1;