package Milton::Command::power;

use strict;
use warnings qw(all -uninitialized);

use Time::HiRes qw(sleep);

use base qw(Milton::Command::ManualTuningCommand);
use Carp;
use Milton::Config::Path qw(resolve_writable_config_path);

use Milton::DataLogger qw(get_namespace_debug_level);

use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_DATA => 100;

=head1 NAME

Milton::Command::power - Operate the hotplate at a constant power level until shut down by the user.

=head1 SYNOPSIS

    use Milton::Command::power;

    my $power = Milton::Command::power->new();

=head1 DESCRIPTION

Operate the hotplate at a constant power level until shut down by the user. The command accepts
a single argument - the power level in watts. It will then maintain the requested power level
until the process is shut down by the user via Ctrl+C, a terminate signal or any other means
by which the process is terminated. Upon shutdown, the command will ensure that the hotplate is
turned off.

=cut

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $self->{power} = $self->{args}->[0] || $config->{power}->{default};

  croak "Power level not specified." unless $self->{power};
  croak "Power level must be a positive number: $self->{power}" unless $self->{power} > 0;
  croak "Power level is crazy high: $self->{power}" unless $self->{power} <= $interface->{power}->{maximum};

  return $self;
}

=head1 OPTIONS

The following command line options are supported:

=over

=item power

The power level in watts. This is equivalent to setting the power via an unqualified numeric argument on the command line, although if both are specified, the unqualified argument takes precedence.

=item run

If set, the command will run continuously until the process is terminated by the user. This is functionally equivalent to setting samples=0.

=item duration

The time to run for in seconds. It set, the command will shut off power and exit after running for the specified duration.

=back

=cut

sub options {
  return ( 'power=i'
         , 'duration=i'
         , 'onepointcal'
         , 'run'
         );
}

sub preprocess {
  my ($self, $status) = @_;

  $self->info("Power: $self->{power}");
  $self->info("Duration: $self->{duration}") if $self->{duration};

  my $controller = $self->{controller};
  if ($self->{onepointcal}) {
    $controller->resetTemperatureCalibration(0);

    if (!exists($status->{ambient})) {
      if ($controller->hasTemperatureDevice) {
        my ($device_temperature, $device_ambient) = $controller->getDeviceTemperature;
        $status->{ambient} = $device_temperature // $device_ambient;
      }
    }
    my $ambient = $status->{ambient};
    my $message = "Ambient temperature not available, please enter it manually: ";
    my $error = '';

    while (!defined($ambient) || $ambient eq '' || $ambient !~ /^\d+(\.\d+)?$/ || $ambient <= 0) {
      $ambient = $self->prompt($message, error => $error);
      
      $error = "Invalid ambient temperature: $ambient\n\n";
    }
    $status->{ambient} = $ambient;
  }

  # Ensure that we have some current through the hotplate so we will be able to measure resistance and set output power.
  $self->{interface}->setCurrent($self->{config}->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll($status);
  
  # Trigger auto-calibration
  $controller->getTemperature($status);

  if ($self->{onepointcal}) {
    $self->writeOnePointCalibration($status);
  }

  return $status;
}

sub _write_data_line {
  my ($self, $fh, $format, @args) = @_;

  my $text = sprintf($format, @args);

  $self->debug($text) if DEBUG_LEVEL >= DEBUG_DATA;
  return $fh->print("$text\n");
}

sub writeOnePointCalibration {
  my ($self, $status) = @_;

  my $controller = $self->{controller};
  my $calibration = $controller->{calibration};
  my $calpath = $calibration->getPath;
  if (!$calpath) {
    $calpath = { filename => 'command/rtd_calibration.yaml' };
  }

  my @points = $controller->getTemperaturePoints;
  my $fullpath = resolve_writable_config_path($calpath->{filename});

  $self->info("Writing one-point calibration data to $fullpath");

  my $fh = $self->replaceFile($fullpath);
  $self->_write_data_line($fh, '---');
  $self->_write_data_line($fh, 'temperatures:');

  foreach my $point (@points) {
    $self->_write_data_line($fh, '- resistance: %f', $point->[0]);
    $self->_write_data_line($fh, '  temperature: %.1f', $point->[1]);

    if (@$point > 2 && exists($point->[2]->{name})) {
      $self->_write_data_line($fh, '  name: %s', $point->[2]->{name});
    }
  }
  $fh->close;

  return $self;
}

sub keyEvent {
  my ($self, $status) = @_;

  if ($status->{key} eq 'q') {
    $self->{'quit-count'}++;

    if ($self->{'quit-count'} > 3) {
      $self->{interface}->shutdown;
      return;
    }
  } elsif ($status->{key} eq 'up') {
    $self->{power} += 1;
  } elsif ($status->{key} eq 'down') {
    $self->{power} -= 1;
  } else {
    $self->{'quit-count'} = 0;
  }

  return $status;
}

sub processTimerEvent {
  my ($self, $status) = @_;

  $self->{controller}->getTemperature($status);

  # We don't need it for control, but getting the predicted temperature is useful for web UI display and data logging.
  my $predictor = $self->{controller}->getPredictor;
  if ($predictor) {
    $predictor->predictTemperature($status);
  }
  $status->{'set-power'} = $self->{power};

  # If we've passed the set duration, then power off and exit.
  if ($self->{duration} && $status->{now} > $self->{duration}) {
    $self->{interface}->on(0);
    $self->beep;
    return;
  }

  if ($self->{detector}) {
    $status->{'steady-state-count'} = $self->{detector}->{count};
    $status->{'filtered-delta'} = $self->{detector}->{'filtered-delta'};

    if ($self->{detector}->check($status->{resistance})) {
      $self->{interface}->off;
      $self->beep;
      return;
    }
  }

  my $power = $self->{controller}->getPowerLimited($status);

  $self->{interface}->setPower($power);

  return $status;
}

1;