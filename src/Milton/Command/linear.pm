package Milton::Command::linear;

use strict;
use warnings qw(all -uninitialized);

use List::Util qw(min max);

use base qw(Milton::Command);
use Milton::Config qw(get_yaml_parser);
use Milton::Math::PiecewiseLinear;
use Data::Dumper;
use Math::Round qw(round);
use Milton::Config::Path qw(resolve_writable_config_path unresolve_file_path);

use Milton::DataLogger qw(get_namespace_debug_level);

use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_CALCULATIONS => 50;
use constant DEBUG_METHOD_ENTRY => 10;
use constant DEBUG_DATA => 100;
use constant DEBUG_VERBOSE => 200;

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  my $profileName = shift @args;

  die "Profile name is required" if !$profileName;

  # Try the name directly, first
  $self->{profile} = Milton::Config->new($profileName, 1);
  # if that doesn't work, try adding routine path elements to the name so users can be lazy
  if (!$self->{profile}) {
    $self->{profile} = Milton::Config->new("command/linear/$profileName.yaml", 1);
  }
  die "Profile '$profileName' not found" if !$self->{profile};

  $self->{'ramp-trim'} = 1.0;
  $self->{'flat-trim'} = 1.0;

  return $self;
}

sub options {
  return qw( tune );
}

sub buildTransferFunction {
  my ($self) = @_;

  $self->debug('buildTransferFunction') if DEBUG_LEVEL >= DEBUG_METHOD_ENTRY;

  my $transferFunction = Milton::Math::PiecewiseLinear->new;

  if (exists $self->{config}->{'transfer-function'}) {
    my $points = $self->{config}->{'transfer-function'};
    foreach my $point (@$points) {
      $transferFunction->addPoint($point->{'temperature'}, $point->{'power'});
    }
  } else {
    # Create a default transfer function based on experiential data
    $transferFunction->addPoint(100, 20);
    $transferFunction->addPoint(153.5, 40);
    $transferFunction->addPoint(195.6, 60);
    $transferFunction->addPoint(224.7, 75);
  }

  $self->{'transfer-function'} = $transferFunction;

  return $transferFunction;
}

sub buildProfile {
  my ($self, $status) = @_;

  $self->debug('buildProfile') if DEBUG_LEVEL >= DEBUG_METHOD_ENTRY;

  my $profile = $self->{profile};
  my $stages = $profile->{stages};
  my $transferFunction = $self->{'transfer-function'};

  my $ideal = Milton::Math::PiecewiseLinear->new(0, $status->{ambient});

  my $prev = { temperature => $status->{ambient}, power => 0 };
  my $when = 0;
  foreach my $stage (@$stages) {
    $when += $stage->{duration};

    #$ideal->addNamedPoint($when, $stage->{temperature}, $stage->{name});

    if (defined $prev) {
      $prev->{'.next'} = $stage;
      $stage->{'.prev'} = $prev;

      if ($prev->{temperature} > $stage->{temperature}) {
        $stage->{'.direction'} = -1;
      } elsif ($prev->{temperature} < $stage->{temperature}) {
        $stage->{'.direction'} = 1;
      } else {
        $stage->{'.direction'} = 0;
      }

      if (!defined $stage->{power}) {
        # Use a default power margin of 20% as a first guess
        my $factor = 1 + 0.2 * $stage->{'.direction'};

        $stage->{power} = $transferFunction->estimate($stage->{temperature}) * $factor;
      }
    }

    $prev = $stage;
  }

  $self->{ideal} = $ideal;

  return $profile;
}

sub preprocess {
  my ($self, $status) = @_;

  $self->debug('preprocess') if DEBUG_LEVEL >= DEBUG_METHOD_ENTRY;

  $self->{'transfer-function'} = $self->buildTransferFunction;
  $self->buildProfile($status);

  # Ensure that we have some current through the hotplate so we will be able to measure resistance and set output power.
  $self->{interface}->setCurrent($self->{config}->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll;

  $self->{controller}->getTemperature($status);
  $self->{'current-stage'} = $self->nextStage($self->{'profile'}->{stages}->[0], $status);

  return $status;
}

sub trimPowerOutput {
  my ($self, $stage) = @_;

  my $prev = $stage->{'.prev'};

  # Only trim based on stages with well-defined start and end temperatures
  # This condition should skip the warm-up stage, no matter what someone names it
  return if !$prev || !$prev->{name};

  # Only trim based on positive ramp stages
  return if $prev->{'.direction'} <= 0;

  # Only trim if we have samples for the stage
  return if !$stage->{'.samples'} || @{$stage->{'.samples'}} < 5;

  my $new_power = $self->calculateNewPower($stage);
  my $trim_factor = $new_power / $stage->{power};

  $self->{'ramp-trim'} = $trim_factor;

  # Wild-arsed guess at this point, but it should push the trim factor closer to 1.0 for flat stages
  # Which is probably what we want based on observations so far.
  #$self->{'flat-trim'} = sqrt($trim_factor);
  $self->{'flat-trim'} = $trim_factor;

  $self->debug('ramp-trim: %.5f, flat-trim: %.5f', $self->{'ramp-trim'}, $self->{'flat-trim'}) if DEBUG_LEVEL >= DEBUG_CALCULATIONS;

  return $trim_factor;
}

sub nextStage {
  my ($self, $stage, $status) = @_;

  return if !$stage;

  $self->beep;

  my $prev = $stage->{'.prev'};
  my $ideal = $self->{ideal};

  delete $self->{'hi-temp'};
  delete $self->{'lo-temp'};

  my $end_time = $status->{now} + $stage->{duration};
  $self->{timeout} = $end_time;
  $ideal->setNamedPoint($end_time, $stage->{temperature}, $stage->{name});
  $ideal->setNamedPoint($end_time + $status->{period}, $stage->{temperature}, '.nextStage');

  $stage->{'.start'} = $status->{now};
  $stage->{'.timeout'} = $self->{timeout};
  $stage->{'.start-temperature'} = $status->{temperature};

  if ($prev && $prev->{name}) {
    $prev->{'.end'} = $status->{now};
    $prev->{'.end-temperature'} = $status->{temperature};
    $ideal->setNamedPoint($prev->{'.end'}, $prev->{temperature}, $prev->{name});
  }

  if ($stage->{'.direction'} > 0) {
    $self->{'hi-temp'} = $stage->{temperature};
    $self->{'lo-temp'} = ($status->{temperature} // $status->{ambient}) - 20;
    $self->{timeout} += $stage->{duration};
  } elsif ($stage->{'.direction'} <0) {
    $self->{'lo-temp'} = $stage->{temperature};
    $self->{'hi-temp'} = min(220, $status->{temperature} + 50);
    $self->{timeout} += $stage->{duration};
  }

  # Trim the output to adjust for load, but only if we're not tuning!
  $self->trimPowerOutput($prev) if !$self->{tune};

  $stage->{'.samples'} = [];

  # Make sure we have an event loop - may not be the case in some unit tests!
  if ($status->{'event-loop'} && exists($stage->{fan})) {
    if ($stage->{fan}) {
      $status->{'event-loop'}->fanStart($status);
    } else {
      $status->{'event-loop'}->fanStop();
    }
  }

  $self->{'current-stage'} = $stage;

  $self->debug('profile pwl: %s', Dumper($self->{ideal})) if DEBUG_LEVEL >= DEBUG_DATA;

  return $stage;
}

sub dumpHash {
  my ($name, $h) = @_;

  my $result = "$name: {";
  my $indent = ' ' x length($result);
  foreach my $key (sort keys %$h) {
    $result .= "\n$indent$key: $h->{$key}";
  }
  $result .= "\n}";

  return $result;
}

sub timerEvent {
  my ($self, $status) = @_;

  $self->debug('timerEvent') if DEBUG_LEVEL >= DEBUG_METHOD_ENTRY;

  $self->{controller}->getTemperature($status);

  # We don't need it for control, but getting the predicted temperature is useful for web UI display and data logging.
  $status->{'predict-temperature'} = $status->{temperature};

  my $stage = $self->{'current-stage'};
  push @{$stage->{'.samples'}}, $status;
  $self->debug('Current stage: %s, temperature: %.1f, hi-temp: %.1f, lo-temp: %.1f, now: %.1f, timeout: %.1f'
             , $stage->{name}
             , $status->{temperature}
             , $self->{'hi-temp'}
             , $self->{'lo-temp'}
             , $status->{now}
             , $self->{timeout}
             ) if DEBUG_LEVEL >= DEBUG_CALCULATIONS;

  if ($status->{now} >= $self->{timeout}) {
    $self->debug('Timeout reached!') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    $stage = $self->nextStage($stage->{'.next'}, $status);
  } elsif (defined($self->{'hi-temp'}) && $status->{temperature} >= $self->{'hi-temp'}) {
    $self->debug('Reached stage high temperature!') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    if ($stage->{'.direction'} < 0) {
      $self->error('Reached stage high temperature during cooling stage! Aborting!');
      return;
    }
    $stage = $self->nextStage($stage->{'.next'}, $status);
  } elsif (defined($self->{'lo-temp'}) && $status->{temperature} <= $self->{'lo-temp'}) {
    $self->debug('Reached stage low temperature!') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    if ($stage->{'.direction'} > 0) {
      $self->error('Reached stage low temperature during heating stage! Aborting!');
      return;
    }
    $stage = $self->nextStage($stage->{'.next'}, $status);
  }
  return if !$stage;
  #$self->debug("keys: ". join(' ', sort keys %$stage) ."\n");
  $self->debug(dumpHash('stage', $stage)) if DEBUG_LEVEL >= DEBUG_VERBOSE;

  # nextStage() builds the ideal profile as it goes, so this needs to be after the ->nextStage() call
  my $ideal = $self->{ideal};
  $status->{'now-temperature'} = $ideal->estimate($status->{now});
  $status->{'then-temperature'} = $ideal->estimate($status->{now} + $status->{period});

  $status->{stage} = $stage->{name};

  my $trimmedPower = $stage->{power};
  if ($stage->{'.direction'} == 0) {
    $trimmedPower = $trimmedPower * $self->{'flat-trim'};
  } elsif ($stage->{'.direction'} > 0) {
    $trimmedPower = $trimmedPower * $self->{'ramp-trim'};
  }

  $self->{interface}->setPower($trimmedPower);
  $status->{'set-power'} = $trimmedPower;
  $self->debug('Stage power: %.1f, trimmed power: %.1f', $stage->{power}, $trimmedPower) if DEBUG_LEVEL >= DEBUG_CALCULATIONS;

  return $status;
}

sub calculateNewPower {
  my ($self, $stage) = @_;

  my $samples = $stage->{'.samples'};

  $self->debug('stage keys: '. join(' ', sort keys %$stage)) if DEBUG_LEVEL >= DEBUG_DATA;
  $self->debug('sample count: %d', scalar(@$samples)) if DEBUG_LEVEL >= DEBUG_DATA;

  my $average_power = 0;
  my $count = 0;
  foreach my $sample (@$samples) {
    if (exists $sample->{power}) {
      $count++;
      $average_power += $sample->{power};
    }
  }
  $average_power /= $count;
  my $holding_power = $self->{'transfer-function'}->estimate($stage->{temperature});
  my $transition_power = $average_power - $holding_power;

  # Get expected delta_T and duration
  my $expected_delta_T = $stage->{temperature} - $stage->{'.prev'}->{temperature};
  my $expected_duration = $stage->{duration};

  # Get the actual delta_T and duration
  my $actual_delta_T = $stage->{'.end-temperature'} - $stage->{'.start-temperature'};
  my $actual_duration = $stage->{'.end'} - $stage->{'.start'};

  if (DEBUG_LEVEL >= DEBUG_CALCULATIONS) {
    $self->debug('tuning stage: %s, power: %.1f, duration: %.1f'
               , $stage->{name}
               , $stage->{power}
               , $stage->{duration}
               );
    $self->debug('holding power: %.1f, transition power: %.1f, average power: %.1f'
               , $holding_power
               , $transition_power
               , $average_power
               );
    $self->debug('temperature: %.1f, previous temperature: %.1f, Expected delta_T: %.1f'
               , $stage->{temperature}
               , $stage->{'.prev'}->{temperature}
               , $expected_delta_T
               );
    $self->debug('Expected duration: %.1f', $expected_duration);
    $self->debug('Start-temperature: %.1f, End-temperature: %.1f, Actual delta_T: %.1f',
               , $stage->{'start-temperature'}
               , $stage->{'end-temperature'}
               , $actual_delta_T
               );
    $self->debug('Start: %.1f, End: %.1f, Actual duration: %.1f'
               , $stage->{'start'}
               , $stage->{'end'}
               , $actual_duration
               );
  }

  my $new_power;

  if ($stage->{'.direction'} == 0) {
    my $ambient = $stage->{'.samples'}->[0]->{ambient};

    my $expected_rel = $stage->{temperature} - $ambient;
    my $actual_rel = $stage->{'.samples'}->[-1]->{temperature} - $ambient;

    $new_power = $average_power;
    
    if ($expected_rel != 0 && $actual_rel != 0) {
      $new_power = $new_power * $expected_rel / $actual_rel;
    } else {
      $self->debug('Skipping power adjustment due to relative temperature zero condition.') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    }

    $self->debug('average power: %.1f, new power: %.1f'
               , $average_power
               , $new_power
               ) if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
  } else {
    my $new_tp = $transition_power;
    if ($actual_delta_T != 0 && $expected_delta_T != 0) {
      $new_tp = $transition_power * $expected_delta_T / $actual_delta_T;
      $self->debug('Skipping transition power calculations due to delta_T zero condition.') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    }
    if ($actual_duration != 0 && $expected_duration != 0) {
      $new_tp = $new_tp * $actual_duration / $expected_duration;
      $self->debug('Skipping transition power calculations due to duration zero condition.') if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
    }
    $new_power = $holding_power + $new_tp;

    $self->debug('new transition power: %.1f, holding power: %.1f, new power: %.1f'
               , $new_tp
               , $holding_power
               , $new_power
               ) if DEBUG_LEVEL >= DEBUG_CALCULATIONS;
  }

  $new_power = round($new_power * 1000) / 1000;

  return $new_power;
}

sub tuneStage {
  my ($self, $stage) = @_;

  my $new_stage = {};

  # Only tune the stage power if the previous stage had a power level and this stage doesn't use the fan
  if ($stage->{'.prev'}->{power} && !$stage->{fan}) {
    $new_stage->{power} = $self->calculateNewPower($stage);
  } else {
    $new_stage->{power} = $stage->{power};
  }

  # Copy anything else from the old stage to the new stage that we haven't adjusted.
  foreach my $key (keys %$stage) {
    # Skip internally created keys
    next if $key =~ /^\./;

    if (!exists $new_stage->{$key} && defined($stage->{$key})) {
      $new_stage->{$key} = $stage->{$key};
    }
  }

  return $new_stage;
}

sub tuneProfile {
  my ($self, $profile) = @_;
  my $stages = $profile->{stages};

  my $new_stages = [];

  foreach my $stage (@$stages) {
    push @$new_stages, $self->tuneStage($stage);
  }

  my $new_profile = { stages => $new_stages };

  my $ypp = get_yaml_parser();
  my $tuned_yaml = $ypp->dump_string($new_profile);
  $self->info($tuned_yaml);

  my $path = $profile->getPath->{fullpath};
  my $relpath = unresolve_file_path($path);
  my $new_path = resolve_writable_config_path($relpath);

  my $fh = $self->replaceFile($new_path->stringify);
  $fh->print($tuned_yaml);
  $fh->close;
  $self->info('Tuned profile saved to %s', $new_path->stringify);
}

sub postprocess {
  my ($self) = @_;

  $self->debug('postprocess') if DEBUG_LEVEL >= DEBUG_METHOD_ENTRY;

  if ($self->{tune}) {
    $self->tuneProfile($self->{profile});
  }
}

1;