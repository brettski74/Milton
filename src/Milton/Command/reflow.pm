package Milton::Command::reflow;

use strict;
use warnings qw(all -uninitialized);
use Math::Round qw(round);
use Carp qw(croak);
use IO::File;
use Milton::Math::Util qw(setDebug setDebugWriter);
use Milton::Config qw(getYamlParser);

use Exporter qw(import);
our @EXPORT_OK = qw(buildProfile);

use base qw(Milton::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  my $stages_hash = {};
  foreach my $stage (@{$self->{config}->{profile}}) {
    $stages_hash->{$stage->{name}} = $stage;
  }
  $self->{stages} = $stages_hash;

  return $self;
}

sub options {
  return qw( tune=s rtdtune=s );
}

sub buildProfile {
  my ($profile, $ambient) = @_;

  my $stages = Milton::Math::PiecewiseLinear->new;
  my $seconds = 0;
  
  # Add a zero-time point if not explicitly specified in the configuraton
#  if ($profile->[0]->{seconds} > 0) {
#
#    $stages->addHashPoints('when', 'temperature',
#    $stages->addHashPoints(0, $ambient, $profile->[0]);
#  }

  for(my $i=0; $i<@$profile; $i++) {
    my $stage = $profile->[$i];
    $seconds += $stage->{seconds};
    $stage->{when} = $seconds;
    #my $name = exists($profile->[$i+1]) ? $profile->[$i+1]->{name} : 'end';

    #$stages->addHashPoints('when' , 'temperature' , $profile->[$i+1]);
    $stages->addHashPoints('when' , 'temperature' , $stage);
  }

  return $stages;
}

sub preprocess {
  my ($self, $status) = @_;

  # Get some current flowing and poll the hotplate state
  $self->startupCurrent($status);
  my $ambient = $status->{ambient};

  $self->debug(10, join(', ', "Ambient temperature: $ambient"
                            , "device-temperature: $status->{'device-temperature'}"
                            , "device-ambient: $status->{'device-ambient'}"
                            , "temperature: $status->{temperature}"
                            , "resistance: $status->{resistance}"
                            )
              );

  $self->{profile} = buildProfile($self->{config}->{profile}, $ambient);
}

sub timerEvent {
  my ($self, $status) = @_;
  my $controller = $self->{controller};

  # Get the expected time of the next sample
  my $now = $status->{now};
  my $period = $status->{period};
  my $then = $status->{then} = $status->{now} + $period;
  my $profile = $self->{profile};

  my ($target_temp, $attributes) = $self->{profile}->estimate($then);
  my $stage = $attributes->{name};
  $status->{'then-temperature'} = $target_temp;
  $status->{'now-temperature'} = $profile->estimate($now);
  $status->{stage} = $stage;

  # Anticipation!
  my $anticipation = $controller->getAnticipation;
  if ($anticipation) {
    my $ant_period = ($anticipation + 1) * $period;
    $status->{'anticipate-temperature'} = $profile->estimate($now + $ant_period);
    $status->{'anticipate-period'} = $ant_period;
  }

  if ($attributes->{'disable-limits'}) {
    $controller->disableLimits;
  } else {
    $controller->enableLimits;
  }

  if ($attributes->{'disable-cutoff'}) {
    $controller->disableCutoff;
  } else {
    $controller->enableCutoff;
  }

  my $power = $controller->getPowerLimited($status);
  $status->{'set-power'} = $power;

  # Make sure we have an event loop - may not be the case in some unit tests!
  if ($status->{'event-loop'}) {
    if ($self->{stages}->{$stage}->{fan}) {
      $status->{'event-loop'}->fanStart($status);
    } else {
      $status->{'event-loop'}->fanStop($status);
    }
  }

  if ($stage ne $self->{'last-stage'}) {
    $self->beep;
  }
  $self->{'last-stage'} = $stage;

  $self->{interface}->setPower($power);

  my $clean_now = round($now/$period)*$period;
  if ($clean_now > $self->{profile}->[-1]->[0]) {
    $self->beep;
    return;
  }

  return $self;
}

sub writeHistory {
  my ($self, $history, $filename) = @_;
  my %header = ( %{$history->[5]} );
  delete $header{last};
  delete $header{next};
  delete $header{'event-loop'};

  my @columns = qw(now resistance power temperature device-temperature predict-temperature last-Tp);
  foreach my $key (@columns) {
    delete $header{$key};
  }
  @columns = ( @columns, sort keys %header );
  my $fh = $self->replaceFile($filename);
  $fh->print(join(',', @columns), "\n");
  foreach my $sample (@$history) {
    if ($sample->{event} eq 'timerEvent') {
      my @row = map { $sample->{$_} } @columns;
      $fh->print(join(',', @row), "\n");
    }
  }
  $fh->close;
}

sub postprocess {
  my ($self, $status, $history) = @_;

  if ($self->{rtdtune}) {
    my $filename = $self->{rtdtune};
    if ($filename !~ /\.yaml$/) {
      $filename .= '.yaml';
    }
    my $fh = $self->replaceFile($filename);
    my @calibration = $self->{controller}->getTemperaturePoints;
    $fh->print("temperatures:\n");
    foreach my $point (@calibration) {
      my $line = "- resistance: $point->[0]\n  temperature: $point->[1]\n";
      $fh->print($line);
      $self->info($line);
    }
    $fh->close;
  }

  if ($self->{tune}) {
    my $predictor = $self->{controller}->getPredictor;

    Milton::Math::Util::setDebug(255);
    Milton::Math::Util::setDebugWriter(sub {
      $self->info($_[0]);
    });

    my $filename = $self->{tune};
    if ($filename !~ /\.yaml$/) {
      $filename .= '.yaml';
    }
    my $csvfile = $filename;
    $csvfile =~ s/\.yaml$/.csv/;
    my $rawfile = $filename;
    $rawfile =~ s/\.yaml$/.raw.csv/;
    $self->writeHistory($history, $rawfile);

    my $results = $predictor->tune($history, parallel => $self->{config}->{tuning}->{parallel});

    my $fh = $self->replaceFile($filename);
    my $ypp = getYamlParser();
    my $tuned_yaml = $ypp->dump_string($results);
    $fh->print($tuned_yaml);
    $fh->close;
    $self->info($tuned_yaml);

    $predictor->initialize;
    foreach my $sample (@$history) {
      if ($sample->{event} eq 'timerEvent') {
        $predictor->predictTemperature($sample);
      }
    }

    $self->writeHistory($history, $csvfile);
  }
}

1;