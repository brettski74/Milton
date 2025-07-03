package PowerSupplyControl::Command::caltemp;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Command::StateMachineCommand);
use Time::HiRes qw(sleep);
use PowerSupplyControl::Config;
use PowerSupplyControl::Math::SteadyStateDetector;
use Carp qw(confess);
use Math::Round qw(round);

sub new {
    my ($class, $config, $interface, $controller, @args) = @_;

    my $self = $class->SUPER::new($config, $interface, $controller, @args);

    $self->{temperatures} = [ sort { $a <=> $b } @{$config->{temperatures}} ];

    if (!defined $self->{ambient}) {
      $self->{ambient} = $self->prompt('Ambient temperature', $config->{'ambient-temperature'} || 25);
    }

    bless $self->{config}, 'PowerSupplyControl::Config';

    return $self;
}

sub defaults {
    return { current => { startup => 2 }
           , cycles => 10
           , filename => 'temperature_calibration.yaml'
           };
}

sub preprocess {
    my ($self, $status) = @_;
    my $interface = $self->{interface};

    $interface->setCurrent($self->{current}->{startup} || 2);
    sleep(0.5);

    $interface->poll($status);
    $self->{controller}->setAmbient($self->{ambient});
    $self->{controller}->resetTemperatureCalibration(0);
    $self->{controller}->getTemperature($status);
    $self->{'calibration-points'} = [ { temperature => $self->{ambient}, resistance => $status->{resistance}, power => 0 } ];

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

  print "All done\n";

  return;
}

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq 's') {
    $self->{'manual-steady-state'}++;
  }

  return $self;
}

sub postprocess {
  my ($self, $status, $history) = @_;
  $self->{interface}->off;
  
  my $config = $self->{config};
  my $interface = $self->{interface};
  my $filename = $config->{'filename'} || 'temperature-calibration.yaml';
  my $fh = $self->replaceFile($filename);

  $fh->print("# Ambient temperature: $self->{ambient}\n");
  $fh->print("# Cycles: $self->{config}->{cycles}\n");
  $fh->print("# Temperatures: " . join(', ', @{$self->{temperatures}}) . "\n");
  $fh->print("# Startup Current: $config->{current}->{startup}\n");
  $fh->print("# Minimum Current: $interface->getMinimumCurrent\n");
  $fh->print("# Maximum Power: $interface->getMaximumPower\n");
  $fh->print("# Steady state samples: $config->{'steady-state'}->{'samples'}\n") if defined $config->{'steady-state'}->{'samples'}; 
  $fh->print("# Steady state smoothing: $config->{'steady-state'}->{'smoothing'}\n") if defined $config->{'steady-state'}->{'smoothing'};
  $fh->print("# Steady state threshold: $config->{'steady-state'}->{'threshold'}\n") if defined $config->{'steady-state'}->{'threshold'};
  $fh->print("# Steady state reset: $config->{'steady-state'}->{'reset'}\n") if defined $config->{'steady-state'}->{'reset'}; 
  $fh->print("\n");

  # Write out RTD calibration
  $fh->print("temperatures:\n");
  print "temperatures:\n";
  foreach my $point (@{$self->{'calibration-points'}}) {
    print "  - resistance: $point->{resistance}\n";
    print "    temperature: $point->{temperature}\n";
    $fh->print("  - resistance: $point->{resistance}\n");
    $fh->print("    temperature: $point->{temperature}\n");
  }

  print "\n";
  $fh->print("\n");

  $fh->print("thermal-resistance:\n");
  print "thermal-resistance:\n";
  foreach my $point (@{$self->{'calibration-points'}}) {
    if ($point->{'thermal-resistance'} > 0) {
      print "  - temperature: $point->{temperature}\n";
      print "    thermal-resistance: $point->{'thermal-resistance'}\n";
      $fh->print("  - temperature: $point->{temperature}\n");
      $fh->print("    thermal-resistance: $point->{'thermal-resistance'}\n");
    }
  }

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
  $self->{'steady-voltage'} = round(sqrt($meanResistance * $self->{'steady-power'}), 2);
  $self->{interface}->setVoltage($self->{'steady-voltage'});
}

sub _bangBang {
  my ($self, $status) = @_;
  my $off = $self->{'transition-count'} % 2;

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
    $self->eventPrompt($status, 'Steady state detected. Enter hotplate temperature: ', qr/[0-9.]/);
    $self->{'steady-samples'} = [ { temperature => $status->{temperature}, power => $status->{power}, resistance => $status->{resistance} } ];
    $self->advanceStage('input', $status);
  }
  #$self->{interface}->setVoltage($self->{'steady-voltage'});
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