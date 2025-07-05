package PowerSupplyControl::Command::hccal;

use strict;
use warnings qw(all -uninitialized);
use Time::HiRes qw(sleep);
use PowerSupplyControl::Math::Util qw(mean);

use base qw(PowerSupplyControl::Command::CalibrationCommand);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $self->{'input'} = PowerSupplyControl::Config->new($config->{filename});
  $config = $self->{'config'};

  if (!defined $self->{ambient}) {
    $self->{ambient} = $self->prompt('Ambient temperature', $config->{'ambient-temperature'} || 25);
  }


  if ($config->{'replace-file'}

  return $self;
}

sub defaults {
  return { current => { startup => 2 }
         , 'calibration-point-offset' => 5
         , 'discard-samples' => 4
         , 'speed' => 1
         , filename => 'thermal-calibration.yaml'
         , 'replace-file' => 1
         };
}

sub _buildEstimator {
  my ($self, $points, $xlabel, $ylabel) = @_;

  my $est = PowerSupplyControl::Math::PiecewiseLinear->new;
  foreach my $point (@$points) {
    $est->addPoint($point->{$xlabel}, $point->{$ylabel});
  }

  return $est;
}

sub _buildSteps {
  my ($self) = @_;
  my $input = $self->{'input'};
  my $config = $self->{'config'};
  my $offset = $config->{'calibration-point-offset'};

  my $steps = [];
  my $speed_factor = 2 * exp(1/$config->{speed}) - 1;

  my $ttr_est = $self->{'ttr-estimator'};
  my $rt_est = $self->{'rt-estimator'};
  my $mid_step = { 'start-temperature' => $self->{'ambient'} };

  my @points = sort { $a->{'temperature'} <=> $b->{'temperature'} } @{$input->{'thermal-resistance'}};
  foreach my $point (@points) {
    my $step = { 'centre-temperature' => $point->{temperature}
               , 'thermal-resistance' => $point->{'thermal-resistance'}
               , 'start-temperature' => $point->{'temperature'} - $offset
               , 'end-temperature' => $point->{'temperature'} + $offset
               , 'final-temperature' => $point->{temperature} + $offset * $speed_factor;
               };

    $step->{'start-hold-power'} = ($step->{'start-temperature'} - $self->{'ambient'}) / $ttr_est->estimate($step->{'start-temperature'});
    $step->{'end-hold-power'} = ($step->{'end-temperature'} - $self->{'ambient'}) / $ttr_est->estimate($step->{'end-temperature'});
    $step->{'step-power'} = ($step->{'final-temperature'} - $self->{'ambient'}) / $ttr_est->estimate($step->{'final-temperature'});
    $step->{'start-resistance'} = $rt_est->estimate($step->{'start-temperature'});
    $step->{'end-resistance'} = $rt_est->estimate($step->{'end-temperature'});

    $mid_step->{'end-temperature'} = $step->{'start-temperature'};
    $mid_step->{'end-hold-power'} = $step->{'start-hold-power'};
    $mid_step->{'centre-temperature'} = ($mid_step->{'start-temperature'} + $mid_step->{'end-temperature'}) / 2;
    $mid_step->{'thermal-resistance'} = $ttr_est->estimate($mid_step->{'centre-temperature'});
    $mid_step->{'start-resistance'} = $rt_est->estimate($mid_step->{'start-temperature'});
    $mid_step->{'end-resistance'} = $step->{'start-resistance'};
    my $false_start = max($mid_step->{'start-temperature'}, $mid_step->{'end-temperature'} - 2 * $offset);
    $mid_step->{'final-temperature'} = ($false_start - $self->{'ambient'}) / $ttr_est->estimate($false_start);
    $mid_step->{'start-resistance'} = $rt_est->estimate($false_start);
    $mid_step->{'step-power'} = ($mid_step->{'final-temperature'} - $self->{'ambient'}) / $ttr_est->estimate($mid_step->{'final-temperature'});

    push @$steps, $mid_step, $step;

    $mid_step = { 'start-temperature' => $step->{'end-temperature'} };
  }

  return $steps;
}

sub calibrationSetup {
  my ($self, $status) = @_;
  my $config = $self->{'config'};
  my $input = $self->{'input'};

  # Ignore the controller completely and create our own estimators for temperature and thermal resistance
  $self->{'rt-estimator'} = $self->_buildEstimator($input->{temperatures}, 'resistance', 'temperature');
  $self->{'tr-estimator'} = $self->_buildEstimator($input->{temperatures}, 'temperature', 'resistance');
  $self->{'ttr-estimator'} = $self->_buildEstimator($input->{'thermal-resistance'}, 'temperature', 'thermal-resistance');

  # Build the list of steps to be run
  $self->{steps} = $self->_buildSteps();

  $self->{stage} = 'step';

  # Make sure that current is flowing so that we can measure resistance
  $self->{interface}->setCurrent($config->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll($status);
}

sub _timerCommonProcessing {
  my ($self, $status) = @_;

  # Use our own temperature calibration
  $status->{temperature} = $self->{'rt-estimator'}->estimate($status->{resistance});

  # Store the current step in the status
  $status->{step} = $self->{steps}->[0];
}

sub _step {
  my ($self, $status) = @_;

  $self->_timerCommonProcessing($status);
  my $step = $status->{step};

  if ($status->{temperature} >= $step->{'end-temperature'}) {
    $self->newSteadyState($status);
    return $self->advanceStage('hold', $status);
  }

  $self->{interface}->setPower($step->{'step-power'});
}

sub _hold {
  my ($self, $status) = @_;

  $self->_timerCommonProcessing($status);

  if ($self->checkSteadyState($status->{resistance})) {
    $self->{'steady-samples'} = [ { temperature => $status->{temperature}, power => $status->{power}, resistance => $status->{resistance} } ];
    $self->eventPrompt('input', $status, 'Steady state detected. Enter hotplate temperature: ', qr/[0-9.]/);
  }

  $self->{interface}->setPower($step->{'end-hold-power'});
}

sub _input {
  my ($self, $status) = @_;

  $self->_timerCommonProcessing($status);

  push @{$self->{'steady-samples'}}, { temperature => $status->{temperature}, power => $status->{power}, resistance => $status->{resistance} };

  $self->{interface}->setPower($step->{'end-hold-power'});
}

sub lineEvent {
  my ($self, $status) = @_;

  shift @{$self->{steps}};

  return $self->advanceStage('step', $status);
}

sub _extractTemperatureData {
  my ($self, $history) = @_;

  my $previous;
  my $temperatures = [];
  my $stepData = [];
  my $holdData = [];
  my $holdIdx = 0;

  foreach my $current (@$history) {
    my $stage = $current->{'stage'};
    my $event = $current->{'event'};

    if ($event eq 'preprocess') {
      # Get the cold temperature resistance of the hotplate
      push @$temperatures, { temperature => $self->{ambient}, resistance => $current->{'resistance'} };
    } elsif ($event eq 'timerEvent') {
      if ($stage eq 'step') {
        push @stepData, $current;
      } elsif ($stage eq 'hold' || $stage eq 'input') {
        # Remember the last steady-state-samples samples
        $holdData[$holdIdx++] = $current;
        if ($holdIdx >= $config->{'steady-state'}->{'samples'}) {
          $holdIdx = 0;
        }
      }
    } elsif ($event eq 'lineEvent') {
      # Two temperature records we need to insert.
      # One is for the hold portion - that is used to determine resistance-temperature mappings and thermal resistance from the hold power
      my $record2 = { temperature => $current->{line} + 0.0 };
      mean($holdData, 'resistance', $record2->{'resistance'}
                    , 'power', $record2->{'power'}
                    );
      $record2->{'thermal-resistance'} = ($record2->{temperature} - $self->{ambient}) / $record2->{power};

      # The other is for the the step portion - that is used to calculate heat capacity based on the first order step response
      my $record1 = { temperature => $current->{line} + 0.0 };
      my $step = $previous->{'step'};
      my $est = PowerSupplyControl::Math::FirstOrderStepEstimator->new(resistance => $step->{'thermal-resistance'});
      # Starting temperature is the temperature of the last temperature record we created
      my $startTemp = $temperatures->[-1]->{'temperature'};
      my $response = $est->fitCurve($stepData, 'now', 'temperature', initial => $startTemp, final => $step->{'final-temperature'});

      $record1->{'heat-capacity'} = $response->{'capacitance'};

      push @$temperatures, $record1, $record2;

      $stepData = [];
      $holdData = [];
      $holdIdx = 0;
    }

    if ($current->{event} eq 'timerEvent') {
      $previous = $current;
    }
  }

  return $temperatures;
}

sub _mergeCalibrations {
  my ($self, $newCalibration) = @_;
  my $input = $self->{'input'};

  my $temps = {};

  # Add in the input resistance-temperature mappings
  foreach my $cal (@{$input->{temperatures}}) {

    # Ignore the old ambient temperature mapping. We'll use our new one for that.
    if ($cal->{temperature} < $self->{ambient}+5) {
      $temps->{$cal->{temperature}} = $cal;
    }
  }
  # Add in the input temperature-thermal resistance mappings
  foreach my $cal (@{$input->{'thermal-resistance'}}) {
    if (exists $temps->{$cal->{temperature}}) {
      $temps->{$cal->{temperature}}->{'thermal-resistance'} = $cal->{'thermal-resistance'};
    } else {
      $temps->{$cal->{temperature}} = $cal;
    }
  }

  # Add in the new calibration
  foreach my $new (@$newCalibration) {
    if (exists $temps->{$new->{temperature}}) {
      my $cal = $temps->{$new->{temperature}};

      if (defined($new->{'heat-capacity'}) && !defined($cal->{'heat-capacity'})) {
        $cal->{'heat-capacity'} = $new->{'heat-capacity'};
      }
      if (defined($new->{'thermal-resistance'}) && !defined($cal->{'thermal-resistance'})) {
        $cal->{'thermal-resistance'} = $new->{'thermal-resistance'};
      }
      if (defined($new->{resistance}) && !defined($cal->{resistance})) {
        $cal->{resistance} = $new->{resistance};
      }
    } else {
      $temps->{$new->{temperature}} = $new;
    }
  }
  return [ sort { $a->{temperature} <=> $b->{temperature} } values %$temps ];
}

sub writeCalibration {
  my ($self, $temperatures) = @_;
  my $config = $self->{config};
  my $filename = $self->{input}->getPath();
  my $fh;

  if ($config->{'replace-file'}) {
    $fh = $self->replaceFile($filename);
  } else {
    $fh = $self->replaceFile($filename .'.'. timestamp())
  }

  $self->SUPER::writeCalibration($fh, $temperatures);

  $fh->close;
}

sub postprocess {
  my ($self, $history) = @_;
  my $previous;
  my $newCalibration = $self->_extractTemperatureData($history);

  my $temperatures = $self->_mergeCalibrations($newCalibration);

  $self->writeCalibration($temperatures);

  return $self;
}