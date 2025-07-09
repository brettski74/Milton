package PowerSupplyControl::Command::rtcal;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Command::CalibrationCommand);
use Time::HiRes qw(sleep);
use PowerSupplyControl::Config;
use PowerSupplyControl::Math::SteadyStateDetector;
use Carp qw(confess);
use Math::Round qw(round);
use Readonly;

sub new {
    my ($class, $config, $interface, $controller, @args) = @_;

    my $self = $class->SUPER::new($config, $interface, $controller, @args);

    $self->{temperatures} = [ sort { $a <=> $b } @{$config->{temperatures}} ];

    return $self;
}

sub defaults {
    return { current => { startup => 2 }
           , cycles => 10
           , filename => 'thermal-calibration.yaml'
           };
}

sub options {
  return ( 'R0=f', 'T0=f' );
}

sub preprocess {
    my ($self, $status) = @_;
    my $interface = $self->{interface};
    my $config = $self->{config};

    $interface->setCurrent($self->{current}->{startup} || 2);
    sleep(0.5);

    $interface->poll($status);
    $self->{controller}->setAmbient($self->{ambient});
    $self->{controller}->resetTemperatureCalibration(0);
    if (!exists($self->{R0}) || !exists($self->{T0})) {
      if (exists($config->{R0}) && exists($config->{T0})) {
        $self->{R0} = $config->{R0};
        $self->{T0} = $config->{T0};
      } else {
        $self->{R0} = $status->{resistance};
        $self->{T0} = $self->{ambient};
      }
    }
    $self->{'calibration-points'} = [ { temperature => $self->{T0}, resistance => $self->{R0} } ];
    $self->{controller}->setTemperaturePoint($self->{T0}, $self->{R0});
    $self->{controller}->getTemperature($status);

    $self->_setupBangBang();

    $self->{stage} = 'bangBang';

    return $self;
}

sub lineEvent {
  my ($self, $status) = @_;

  my $mean_power = 0;
  my $mean_resistance = 0;

  print "lineEvent: " . $status->{'sample-count'} . "\n";

  foreach my $sample (@{$self->{'steady-samples'}}) {
    $mean_power += $sample->{power};
    $mean_resistance += $sample->{resistance};
  }

  $mean_power /= scalar @{$self->{'steady-samples'}};
  $mean_resistance /= scalar @{$self->{'steady-samples'}};
  
  print "mean_power: $mean_power\n";
  print "mean_resistance: $mean_resistance\n";

  my $temperature = $status->{line} + 0.0;
  my $thermal_resistance = ($temperature - $self->{ambient}) / $mean_power;

  print "temperature: $temperature\n";
  print "thermal_resistance: $thermal_resistance\n";

  push @{$self->{'calibration-points'}}, { temperature => $temperature
                                         , resistance => $mean_resistance
                                         , power => $mean_power
                                         , 'thermal-resistance' => $thermal_resistance
                                         };

  print "calibration-points: " . scalar @{$self->{'calibration-points'}} . "\n";

  $self->{controller}->resetTemperatureCalibration(1);
  foreach my $point (@{$self->{'calibration-points'}}) {
    $self->{controller}->setTemperaturePoint($point->{temperature}, $point->{resistance});
  }

  print "calibration reset complete\n";

  if (scalar @{$self->{temperatures}}) {
    $self->_setupBangBang();
    $self->advanceStage('bangBang', $status);
    return $self;
  }

  $self->allDone($status->{'event-loop'}->getHistory());
  return $self->advanceStage('fanCoolDown', $status);
}

Readonly my %ADJUSTMENTS => ( up => 0.01
                            , down => -0.01
                            , pageup => 0.1
                            , pagedown => -0.1
                            );

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq 's') {
    $self->{'manual-steady-state'}++;
  } elsif (exists $ADJUSTMENTS{$status->{key}}) {
    $self->{adjustment}++;
    my $adjusted = $self->{'steady-voltage'} + $ADJUSTMENTS{$status->{key}};
    $self->{'steady-voltage'} = round($adjusted * 100.0) / 100.0;
  }

  return $self;
}

=head2 allDone($status, $history)

Called when the calibration is complete. This would have normally been a postprocess command,
but we may want to do fan cooldown and we don't want to wait until that's done and something
possibly crashes and we lose all this precious data, so let's just write it now and be done
with it. Too bad if it takes longer than a sample period - we're done sampling anyway.

=cut

sub allDone {
  my ($self, $status, $history) = @_;
  $self->{interface}->off;
  
  my $config = $self->{config};
  my $interface = $self->{interface};
  my $filename = $config->{'filename'} || 'temperature-calibration.yaml';
  my $fh = $self->replaceFile($filename);

  return $self->writeCalibration($fh
                               , $self->{'calibration-points'}
                               , 'Ambient temperature' => $self->{ambient}
                               , 'Cycles' => $self->{config}->{cycles}
                               , 'Temperatures' => join(', ', @{$self->{temperatures}})
                               , 'Startup Current' => $config->{current}->{startup}
                               , 'Minimum Current' => $interface->getMinimumCurrent
                               , 'Maximum Power' => $interface->getMaximumPower
                               , 'Steady state samples' => $config->{'steady-state'}->{'samples'}
                               , 'Steady state smoothing' => $config->{'steady-state'}->{'smoothing'}
                               , 'Steady state threshold' => $config->{'steady-state'}->{'threshold'}
                               , 'Steady state reset' => $config->{'steady-state'}->{'reset'}
                               );
  $fh->close;

  return $self;
}

sub _setupBangBang {
  my ($self) = @_;

  $self->{'transition-count'} = 0;
  $self->{'transition-skip'} = $self->{config}->{cycles}->{skip} * 2;
  $self->{'transition-end'} = $self->{'transition-skip'} + $self->{config}->{cycles}->{capture} * 2;
  $self->{'target-temperature'} = shift @{$self->{temperatures}};
  $self->{interface}->setPower($self->{interface}->getMaximumPower());
  $self->{'samples'} = [];

  print "Banging up to $self->{'target-temperature'} celsius\n";

  return $self;
}

sub _setupSteady {
  my ($self, $status) = @_;

  my $meanTemperature = 0;
  my $meanPower = 0;
  my $meanResistance = 0;
  my $samples = $self->{'samples'};

  foreach my $sample (@{$samples}) {
    $meanTemperature += $sample->{temperature};
    $meanPower += $sample->{power};
    $meanResistance += $sample->{resistance};
  }

  $meanTemperature /= scalar @$samples;
  $meanPower /= scalar @$samples;
  $meanResistance /= scalar @$samples;

  $self->{'steady-state'} = PowerSupplyControl::Math::SteadyStateDetector->new(%{$self->{config}->clone('steady-state')});
  $self->{'manual-steady-state'} = 0;

  $self->{'steady-power'} = $meanPower * ($self->{'target-temperature'} - $self->{'ambient-temperature'}) / ($meanTemperature - $self->{'ambient-temperature'});
  $self->{'steady-voltage'} = round(sqrt($meanResistance * $self->{'steady-power'}) * 100.0) / 100.0;
  $self->{adjustment} = 0;
  $self->{interface}->setVoltage($self->{'steady-voltage'});
}

sub _bangBang {
  my ($self, $status) = @_;
  my $off = $self->{'transition-count'} % 2;

#  print "BangBang: ". ($off ? 'off' : 'on') . ", transition-count: $self->{'transition-count'}, power: $status->{power}, resistance: $status->{resistance}\n";
#  print "BangBang: (". join(', ', sort keys %$status) ."), temperature: $status->{temperature}\n";

  if ($self->{'transition-count'} >= $self->{'transition-skip'}) {
    push @{$self->{'samples'}}, { temperature => $status->{temperature}
                                , power => $status->{power}
                                , resistance => $status->{resistance}
                                };
  }

  $status->{'sample-count'} = scalar @{$self->{'samples'}};
  $status->{'transition-count'} = $self->{'transition-count'};

  if ($off) {
    if ($status->{temperature} < $self->{'target-temperature'}) {
      $self->{interface}->setPower($self->{interface}->getMaximumPower());
      $self->{'transition-count'}++;
    } else {
      $self->{interface}->setPower(0.01);
    }
  } else {
    if ($status->{temperature} > $self->{'target-temperature'}) {
      $self->{'transition-count'}++;
      if ($self->{'transition-count'} >= $self->{'transition-end'}) {
        $self->_setupSteady();
        return $self->advanceStage('steady', $status);
      } 

      # Set power to a really low value and let the interface minimums apply
      $self->{interface}->setPower(0.01);
    } else {
      $self->{interface}->setPower($self->{interface}->getMaximumPower());
    }
  }

  return $self;
}

sub _steady {
  my ($self, $status) = @_;

  if ($self->{'steady-state'}->check($status->{resistance}) || $self->{'manual-steady-state'} >= 3) {
    $self->{'steady-samples'} = [ { temperature => $status->{temperature}, power => $status->{power}, resistance => $status->{resistance} } ];
    $self->eventPrompt('input', $status, 'Steady state detected. Enter hotplate temperature: ', qr/[0-9.]/);
  }

  # Only set the voltage if there was an adjustment requested
  if ($self->{adjustment}) {
    $self->{interface}->setVoltage($self->{'steady-voltage'});
    $self->{adjustment} = 0;
    print "Adjusted steady voltage to $self->{'steady-voltage'}\n";
  }

  $status->{'steady-state-count'} = $self->{'steady-state'}->{count};
  $status->{'filtered-delta'} = $self->{'steady-state'}->{'filtered-delta'};

  return $self;
}

sub _input {
  my ($self, $status) = @_;

  push @{$self->{'steady-samples'}}, { temperature => $status->{temperature}, power => $status->{power}, resistance => $status->{resistance} };
  #$self->{interface}->setVoltage($self->{'steady-voltage'});
  $status->{'steady-state-count'} = $self->{'steady-state'}->{count};
  $status->{'filtered-delta'} = $self->{'steady-state'}->{'filtered-delta'};

  return $self;
}

1;