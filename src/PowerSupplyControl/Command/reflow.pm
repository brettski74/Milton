package PowerSupplyControl::Command::reflow;

use strict;
use warnings qw(all -uninitialized);
use Math::Round qw(round);
use Carp qw(croak);
use IO::File;
use PowerSupplyControl::Math::Util qw(setDebug setDebugWriter);

use base qw(PowerSupplyControl::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  return $self;
}

sub options {
  return qw( tune=s );
}

sub _buildProfile {
  my ($self) = @_;

  my $profile = $self->{config}->{profile};
  my $stages = PowerSupplyControl::Math::PiecewiseLinear->new;
  my $seconds = 0;
  
  # Add a zero-time point if not explicitly specified in the configuraton
  if ($profile->[0]->{seconds} > 0) {
    $stages->addNamedPoint(0, $self->{ambient}, $profile->[0]->{name});
    $self->debug(10, "Adding point 0: $self->{ambient} $profile->[0]->{name}");
  }

  for(my $i=0; $i<@$profile; $i++) {
    my $stage = $profile->[$i];
    $seconds += $stage->{seconds};
    my $name = exists($profile->[$i+1]) ? $profile->[$i+1]->{name} : 'end';

    $stages->addNamedPoint($seconds
                         , $stage->{temperature}
                         , $name
                         );
    $self->debug(10, "Adding point $seconds: $stage->{temperature} $name");
  }

  return $stages;
}

sub preprocess {
  my ($self, $status) = @_;

  my $ambient = $status->{ambient};

  # Get some current flowing and poll the hotplate state
  #$self->{interface}->setCurrent($self->{config}->{current}->{startup});
  $self->{interface}->setVoltage($self->{config}->{voltage}->{startup});
  sleep(0.5);
  $self->{interface}->poll($status);

  if (!defined $ambient) {
    $self->{controller}->getTemperature($status);
    $ambient = $status->{temperature};
    $status->{ambient} = $ambient;
  }
  $self->{ambient} = $ambient;
  $self->debug(10, join(', ', "Ambient temperature: $ambient"
                            , "device-temperature: $status->{'device-temperature'}"
                            , "device-ambient: $status->{'device-ambient'}"
                            , "temperature: $status->{temperature}"
                            , "resistance: $status->{resistance}"
                            )
              );

  $self->{profile} = $self->_buildProfile();
}

sub timerEvent {
  my ($self, $status) = @_;

  # Get the expected time of the next sample
  my $now = $status->{now};
  my $period = $status->{period};
  my $then = $status->{then} = $status->{now} + $period;
  my $profile = $self->{profile};


  my ($target_temp, $stage) = $self->{profile}->estimate($then);
  $status->{'then-temperature'} = $target_temp;
  $status->{'now-temperature'} = $profile->estimate($now);
  $status->{'stage'} = $stage;

  my $power = $self->{controller}->getRequiredPower($status);
  $status->{'set-power'} = $power;

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

sub postprocess {
  my ($self, $status, $history) = @_;
  if ($self->{tune}) {
    my $predictor = $self->{controller}->getPredictor;

    PowerSupplyControl::Math::Util::setDebug(255);
    PowerSupplyControl::Math::Util::setDebugWriter(sub {
      $self->info($_[0]);
    });

    my $results = $predictor->tune($history);
    my $filename = $self->{tune};
    if ($filename !~ /\.yaml$/) {
      $filename .= '.yaml';
    }
    my $csvfile = $filename;
    $csvfile =~ s/\.yaml$/.csv/;

    my $fh = $self->replaceFile($filename);
    foreach my $key (keys %$results) {
      print $fh "$key: $results->{$key}\n";
      $self->info("Tune: $key: $results->{$key}");
    }
    $fh->close;

    $fh = $self->replaceFile($csvfile);
    my %header = ( %{$history->[3]} );
    my @columns = qw(now resistance power temperature device-temperature last-Tp);
    foreach my $key (@columns) {
      delete $header{$key};
    }
    @columns = ( @columns, keys %header );
    $fh->print(join(',', @columns), "\n");

    $predictor->initialize;
    foreach my $sample (@$history) {
      if ($sample->{event} eq 'timerEvent') {
        $predictor->predictTemperature($sample);
        my @row = map { $sample->{$_} } @columns;
        $fh->print(join(',', @row), "\n");
      }
    }
    $fh->close;
  }
}

1;