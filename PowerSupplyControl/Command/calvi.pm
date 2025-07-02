package PowerSupplyControl::Command::calvi;

use strict;
use warnings qw(all -uninitialized);
use Time::HiRes qw(sleep);
use base qw(PowerSupplyControl::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  return $self;
}

sub defaults {
  return { samples => 10
         , filename => 'power_supply_calibration.yaml' };
}

sub _handleSignals {
  my ($self) = @_;
  my $handler = sub {
    $self->{interface}->off(1);
    exit 0;
  };

  $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = $handler;
}

sub preprocess {
  my ($self, $status) = @_;

  $self->_handleSignals;
  $self->{interface}->resetCalibration();

  $self->beep;
  $self->prompt(<<'EOS');
Set up for current calibration.  You should have your multimeter in series with your hotplate and connected to
the power supply.  The power supply should be on and connected to your PC, but the outputs should be off.

****           YOUR HOTPLATE MAY GET QUITE HOT DURING THIS PROCESS.           ****
****    YOU MAY WANT TO USE A FAN TO COOL IT DOWN IF YOU HAVE ONE AVAILABLE   ****

Press Enter when ready to continue...
EOS

  $self->{'current-calibration'} = $self->_calibrateCurrent($status);

  $self->beep;
  $self->prompt(<<'EOS');
Set up for voltage calibration.  You should have your multimeter in parallel with your hotplate with both
connected to the power supply.  The power supply should be on and connected to your PC, but the outputs should
be off.

****                        YOUR HOTPLATE MAY GET QUITE HOT DURING THIS PROCESS.                        ****
****    Monitor the temperature, but avoid fans. Higher temperatures will help with higher voltages.    ****

Press Enter when ready to continue...
EOS

  $self->{'voltage-calibration'} = $self->_calibrateVoltage($status);

  return $self;
}

sub postprocess {
  my ($self) = @_;

  my $filename = $self->{config}->{filename};
  my $fh = $self->replaceFile($filename);
  $self->_writeCalibration('current', $fh, $self->{'current-calibration'});
  $self->_writeCalibration('voltage', $fh, $self->{'voltage-calibration'});
  $fh->close;

  return $self;
}

sub _writeCalibration {
  my ($self, $name, $fh, $points) = @_;

  $fh->print("$name:\n");
  foreach my $point (@{$points}) {
    $fh->printf("  - requested: %.5f\n", $point->{'requested'});
    $fh->printf("    sampled: %.5f\n", $point->{'sampled'});
    $fh->printf("    actual: %.5f\n", $point->{'actual'});
  }
}

sub _calibrateCurrent {
  my ($self, $status) = @_;
  my $interface = $self->{interface};
  my $samples = $self->{config}->{samples};
  my ($minCurrent, $maxCurrent) = $interface->getCurrentLimits;
  my $points = [];

  for (my $current = $maxCurrent; $current >= $minCurrent; $current -= ($current > 2 ? 1 : 0.2)) {
    # Put the power supply in constant current mode
    $interface->setCurrent($current);

    my $sum = 0;
    for (my $i=0; $i<$samples; $i++) {
      sleep(1.0);
      $interface->poll($status);
      $sum += $status->{current};
    }

    $self->beep;
    my $point = { sampled => $sum / $samples, requested => $current, actual => $self->prompt("Enter the actual current: ") };
    push(@$points, $point);
  }

  $interface->off(1);

  return $points;
}

sub _calibrateVoltage {
  my ($self, $status) = @_;
  my $interface = $self->{interface};
  my $samples = $self->{config}->{samples};
  my ($minVoltage, $maxVoltage) = $interface->getVoltageLimits;
  my ($minCurrent, $maxCurrent) = $interface->getCurrentLimits;

  my $points = [];

  for (my $voltage = $maxVoltage; $voltage >= $minVoltage; $voltage -= ($voltage > 2 ? 1 : 0.2)) {
    $interface->setVoltage($voltage);
    my $sum = 0;
    for (my $i=0; $i<$samples; $i++) {
      sleep(1.0);
      $interface->poll($status);

      # Test if we're in constant current mode by checking whether the output current is closer to the set voltage or max current
      if (abs($status->{current} - $maxCurrent) < abs($status->{voltage} - $voltage)) {
        $voltage--;
        $i = -1;
        $sum = 0;
        $interface->setVoltage($voltage);
      } else {
        $sum += $status->{voltage};
      }
    }

    $self->beep;
    my $point = { sampled => $sum / $samples, requested => $voltage, actual => $self->prompt("Enter the actual voltage: ") };
    push(@$points, $point);
  }

  $interface->off(1);

  return $points;
}

sub DESTROY {
  my ($self) = @_;

  $self->{interface}->off(1);
}

1;