package Milton::Command::rth;

use strict;
use warnings qw(all -uninitialized);
use List::Util qw(min);
use base qw(Milton::Command);

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
temperature. It will do this using the current control algorithm and parameters until a fixed period of time has
elapsed. At the end of the preheat stage, the power and temperature settings from the last portion of the preheat
stage are averaged. From this, the power level required to hold at the test temperature is estimated.

Next is the soak stage. The hotplate will be operated at constant power using the power level estimated at the end
of the preheat stage. The hotplate will be operated at this power level until a fixed period of time has elapsed.
At the end of the soak stage, the power and temperature settings are averaged again and a new estimate of the holding
power is calculated.

The final stage if the measurement stage. The hotplate will be operated at constant power using the power level
estimated at the end of the soak stage. After a fixed period of time, the hotplate will be turned off and the power
and temperature samples from the last portion of the measurement stage are averaged and used to calculate the
thermal resistance of the complete assembly - which includes the hotplate. This is then refined using the contact
dimensions provided for the assembly under test and the dimensions of the hotplate to estimate the thermal resistance
of the assembly under test (ie. without the hotplate).

The command can also be run in calibration mode. In this mode, the hotplate is run through a test cycle unloaded, but
the contact dimensions provided are the dimensions of the hotplate itself. Calibration mode also accepts an additional
parameter to set the test temperature. At the end of the cycle, the measurements along with the dimensions and test
temperature are written to a configuration file for use in future real tests.

=head1 CONSTRUCTOR

=head2 new($config, $interface, $controller, @args)

Create a new RTH command object.

=cut

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $config->{'test-delta-T'} //= 50;
  $config->{'preheat-time'} //= 180;
  $config->{'soak-time'} //= 240;
  $config->{'measure-time'} //= 240;
  $config->{'sample-time'} //= 60;
  $config->{'length'} //= 100;
  $config->{'width'} //= 100;

  if ($self->{filename}) {
    $self->{calibration} = $self->{filename};
  }

  # Set up parameters, depends on whether we're in calibration or measurement mode
  if (! $self->{calibration}) {
    # Delete any parameters that cannot be set during measurement mode
    foreach my $key (qw(test-delta-T preheat-time soak-time measure-time sample-time)) {
      delete $self->{$key};
    }
  }

  # Delete any keys that should not exist in a new command object - ie. operational state variables
  foreach my $key (qw(samples mean-power mean-temperature test-temperature)) {
    delete $self->{$key};
  }

  foreach my $key (qw(test-delta-T preheat-time soak-time measure-time sample-time length width)) {
    if (!exists $self->{$key}) {
      $self->{$key} = $config->{$key};
    }
  }

  $self->{'stages'} = [ qw(preheat soak measure) ];

  return $self;
}

sub options {
  return ( 'length=i'
         , 'width=i'
         , 'test-delta-T=i'
         , 'preheat-time=i'
         , 'soak-time=i'
         , 'measure-time=i'
         , 'sample-time=i'
         , 'calibration'
         , 'filename=s'
         );
}

sub averageSamples {
  my ($self, $samples) = @_;

  return if !@$samples;

  my $mean_power = 0;
  my $mean_temperature = 0;

  foreach my $sample (@$samples) {
    $mean_power += $sample->{'power'};
    $mean_temperature += $sample->{'temperature'};
  }

  $mean_power /= scalar(@$samples);
  $mean_temperature /= scalar(@$samples);

  $self->info("Rth Mean power: $mean_power");
  $self->info("Rth Mean temperature: $mean_temperature");

  return ($mean_power, $mean_temperature);
}

sub preprocess {
  my ($self, $status) = @_;
  my $config = $self->{config};

  $self->startupCurrent($status);

  $self->{'test-temperature'} = $status->{ambient} + $self->{'test-delta-T'};

  $self->info("Rth Ambient temperature: $status->{ambient}");
  $self->info("Rth Test temperature: $self->{'test-temperature'}");

  foreach my $key (qw(test-delta-T preheat-time soak-time measure-time sample-time length width)) {
    $self->info("$key: $self->{$key}");
  }

  $self->info("Hotplate length: $config->{'length'}");
  $self->info("Hotplate width: $config->{'width'}");
  $self->info("Hotplate R_th: $config->{'hotplate-rth'}");

  $self->newStage;

  return $status;
}

sub newStage {
  my ($self) = @_;

  if ($self->{samples} && @{$self->{samples}}) {
    ($self->{'mean-power'}, $self->{'mean-temperature'}) = $self->averageSamples($self->{samples});
  }

  $self->{stage} = shift @{$self->{stages}};
  $self->{samples} = [];
  $self->{'stage-end'} = $self->{'stage-end'} + $self->{$self->{stage} .'-time'};
  $self->{'sample-start'} = $self->{'stage-end'} - $self->{'sample-time'};
}

sub timerEvent {
  my ($self, $status) = @_;
  my $now = $status->{now};

  $status->{stage} = $self->{stage};

  if ($now > $self->{'stage-end'}) {
    $self->newStage;
    if ($now > $self->{'stage-end'}) {
      # We've hit the end of the cycle!
      return;
    }
    my $rel_temp = $self->{'mean-temperature'} - $status->{ambient};
    $self->{'set-power'} = $self->{'mean-power'} * $self->{'test-delta-T'} / $rel_temp;
    $self->info("Rth Set power: $self->{'set-power'}");
  }

  if ($status->{now} > $self->{'sample-start'}) {
    push(@{$self->{samples}}, $status);
  }

  # Anticipation!
  my $anticipation = $self->{controller}->getAnticipation;
  if ($anticipation) {
    my $ant_period = ($anticipation + 1) * $status->{period};
    $status->{'anticipate-temperature'} = $self->{'test-temperature'};
    $status->{'anticipate-period'} = $ant_period;
  }

  $status->{'then-temperature'} = $self->{'test-temperature'};
  $status->{'now-temperature'} = $self->{'test-temperature'};

  if (exists $self->{'set-power'}) {
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
  $self->info("Power: $self->{'mean-power'}");
  $self->info("Temperature: $self->{'mean-temperature'}");

  my $total_rth = ($self->{'mean-temperature'} - $status->{ambient}) / $self->{'mean-power'};
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