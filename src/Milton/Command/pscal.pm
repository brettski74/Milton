package Milton::Command::pscal;

use strict;
use warnings qw(all -uninitialized);
use Time::HiRes qw(sleep);
use base qw(Milton::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  $config->{samples} //= 10;
  $config->{filename} //= 'power_supply_calibration.yaml';

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  return $self;
}

sub options {
  return qw(imax=f vmax=f);
}

sub _handleSignals {
  my ($self) = @_;
  my $handler = sub {
    $self->{interface}->on(0);
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
  my ($vmin, $vmax) = $interface->getVoltageLimits;
  my ($imin, $imax) = $interface->getCurrentLimits;
  my $points = [];

  if ($self->{imax}) {
    $imax = $self->{imax};
  }

  for (my $current = $imax; $current >= $imin; $current -= ($current > 2 ? 1 : 0.2)) {
    # Set the voltage to the maximum value to ensure we can hit the higest currents
    $interface->setVoltage($vmax);

    # Put the power supply in constant current mode
    $interface->setCurrent($current);

    my $sum = 0;
    for (my $i=0; $i<$samples; $i++) {
      sleep(1.0);
      $interface->poll($status);

      # Test if we're in constant current mode by checking whether the output current is closer to the set current or max voltage
      if (abs($status->{current} - $current) > abs($status->{voltage} - $vmax)) {
        $current--;
        $i = -1;
        $sum = 0;
        $interface->setCurrent($current);
      } else {
        $sum += $status->{current};
      }
    }

    $self->beep;
    my $point = { sampled => $sum / $samples, requested => $current, actual => $self->prompt("Enter the actual current: ") };
    push(@$points, $point);
  }

  $interface->on(0);

  return $points;
}

sub _calibrateVoltage {
  my ($self, $status) = @_;
  my $interface = $self->{interface};
  my $samples = $self->{config}->{samples};
  my ($vmin, $vmax) = $interface->getVoltageLimits;
  my ($imin, $imax) = $interface->getCurrentLimits;

  my $points = [];

  if ($self->{vmax}) {
    $vmax = $self->{vmax};
  }

  for (my $voltage = $vmax; $voltage >= $vmin; $voltage -= ($voltage > 2 ? 1 : 0.2)) {
    # Set the current to the maximum value to ensure we can hit the highest voltages  
    $interface->setCurrent($imax);

    $interface->setVoltage($voltage);
    my $sum = 0;
    for (my $i=0; $i<$samples; $i++) {
      sleep(1.0);
      $interface->poll($status);

      # Test if we're in constant current mode by checking whether the output current is closer to the set voltage or max current
      if (abs($status->{current} - $imax) < abs($status->{voltage} - $voltage)) {
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

  $interface->on(0);

  return $points;
}

sub DESTROY {
  my ($self) = @_;

  $self->{interface}->on(0);
}

1;