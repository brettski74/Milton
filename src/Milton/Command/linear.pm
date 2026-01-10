package Milton::Command::linear;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  my $profileName = shift @args;

  die "Profile name is required" if !$profileName;

  # Try the name directly, first
  $self->{profile} = Milton::Config->new($profileName);
  # if that doesn't work, try adding routine path elements to the name so users can be lazy
  if (!$self->{profile}) {
    $self->{profile} = Milton::Config->new("command/linear/$profileName.yaml");
  }
  die "Profile '$profileName' not found" if !$self->{profile};

  $self->buildTransferFunction;
  $self->buildProfile;

  return $self;
}

sub buildTransferFunction {
  my ($self) = @_;
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
}

sub buildProfile {
  my ($self) = @_;
  my $stages = $self->{profile}->{stages};
  my $transferFunction = $self->{transferFunction};

  my $prev = undef;
  foreach my $stage (@$stages) {
    if (defined $prev) {
      $prev->{next} = $stage;
      $stage->{prev} = $prev;

      if ($prev->{temperature} > $stage->{temperature}) {
        $stage->{direction} = -1;
      } elsif ($prev->{temperature} < $stage->{temperature}) {
        $stage->{direction} = 1;
      } else {
        $stage->{direction} = 0;
      }

      $stage->{'test-temperature'} = $stage->{temperature} * $stage->{direction};

      if (!defined $stage->{power}) {
        # Use a default power margin of 20% as a first guess
        my $factor = 1 + 0.2 * $stage->{direction};

        $stage->{power} = $transferFunction->estimate($stage->{temperature}) * $factor;
      }
    }

    $prev = $stage;
  }
}

sub preprocess {
  my ($self, $status) = @_;

  # Ensure that we have some current through the hotplate so we will be able to measure resistance and set output power.
  $self->{interface}->setCurrent($self->{config}->{current}->{startup});
  sleep(0.5);
  $self->{interface}->poll;

  return $status;
}

sub nextStage {
  my ($self, $stage) = @_;

  return $stage->{next};
}

sub processTimerEvent {
  my ($self, $status) = @_;

  $self->{controller}->getTemperature($status);

  # We don't need it for control, but getting the predicted temperature is useful for web UI display and data logging.
  my $predictor = $self->{controller}->getPredictor;
  if ($predictor) {
    $predictor->predictTemperature($status);
  }

  my $stage = $self->{'current-stage'};
  return if !$stage;
  my $test_temp = $status->{temperature} * $stage->{direction};

  if ($test_temp > $stage->{'test-temperature'}) {
    $self->{stage} = $self->nextStage($status);
    $self->beep;
  }

  $status->{stage} = $stage->{name};

  $self->{interface}->setPower($stage->{power});
  $status->{'set-power'} = $stage->{power};

  return $status;
}

sub postprocess {
}

1;