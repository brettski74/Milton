package Milton::Predictor;

use strict;
use warnings qw(all -uninitialized);

use POSIX qw(floor);

use Milton::Math::Util qw(minimumSearch);

sub new {
  my ($class, %options) = @_;

  my $self = { %options };

  bless $self, $class;

  $self->initialize;

  return $self;
}

sub setPredictedTemperature {
  my ($self, $temperature) = @_;

  $self->{'last-prediction'} = $temperature;
}

sub predictTemperature {
  # Suggestion only for use during testing.
  my ($self, $status) = @_;

  my $prediction;
  if (exists $status->{suggestion}) {
    $prediction = $status->{suggestion};
  } else {
    $prediction = $status->{temperature};
  }
  $self->{'last-prediction'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub tune {
  my ($self, $samples) = @_;

  return;
}

sub initialize {
  return;
}

# break the history into bands based on temperature ranges.
sub buildSampleBands {
  my ($self, $samples, $bands) = @_;
  
  $bands //= [ { min => 0, max => 110, samples => [] }
             , { min => 90, max => 160, samples => [] }
             , { min => 140, max => 210, samples => [] }
             , { min => 190, max => 260, samples => [] }
             ];

  # First find the peak of the reflow curve
  my $peak_idx = 0;
  my $peak_temp = -9999999999999;
  my $stage_bands = 0;
  for (my $i = 0; $i < @$samples; $i++) {
    if ($samples->[$i]->{temperature} > $peak_temp) {
      $peak_idx = $i;
      $peak_temp = $samples->[$i]->{temperature};
    }

    if ($samples->[$i]->{stage} =~ /^band(\d+)-(\d+)$/) {
      my $idx = $1 + 0;
      if (@$bands > $idx) {
        $stage_bands = 1;
        $bands->[$idx]->{centre} = $2 + 0;
      }
    }
  }

  $self->info("Stage Bands: $stage_bands");

  # Figure out the bounds for each band
  if (!$stage_bands) {
    for (my $i=0; $i<@$samples; $i++) {
      foreach my $band (@$bands) {
        if ($samples->[$i]->{temperature} >= $band->{min} && $samples->[$i]->{temperature} <= $band->{max}) {
          if ($i < $peak_idx) {
            if (!exists $band->{'rising_start'}) {
              $band->{'rising_start'} = $i;
            }
            $band->{'rising_end'} = $i;
          } else {
            if (!exists $band->{'falling_start'}) {
              $band->{'falling_start'} = $i;
            }
            $band->{'falling_end'} = $i;
          }
        }
      }
    }
  }

  # Gather the samples into bands based on the detected bounds
  for (my $i=0; $i<@$samples; $i++) {
    next if $samples->[$i]->{event} ne 'timerEvent';
    my $sample = $samples->[$i];

    if ($stage_bands) {
      if ($sample->{stage} =~ /^band(\d+)-(\d+)$/) {
        my $idx = $1 + 0;
        if (@$bands > $idx) {
          push @{$bands->[$idx]->{samples}}, $sample;
        }
      }
    } else {
      foreach my $band (@$bands) {
        if (exists $band->{'rising_start'} && $i >= $band->{'rising_start'} && $i <= $band->{'rising_end'}) {
          push @{$band->{samples}}, $sample;
        }
        if (exists $band->{'falling_start'} && $i >= $band->{'falling_start'} && $i <= $band->{'falling_end'}) {
          push @{$band->{samples}}, $sample;
        }
      }
    }
  }

  return $bands;
}

sub filterSamples {
  my ($self, $samples, $filter) = @_;

  my $tmco = $self->{'time-cut-off'} // 240;
  my $tpco = $self->{'temperature-cut-off'} // 120;

  if (!defined $filter || !ref($filter)) {
    my $expected = $filter // 'device-temperature';

    $filter //= sub {
      return $_[0]->{now} < $tmco || $_[0]->{$expected} > $tpco;
    };
  }

  # Find the last sample that meets the filter criteria
  my $last = 0;
  for (my $i = 0; $i < @$samples; $i++) {
    my $sample = $samples->[$i];
    if ($sample->{event} eq 'timerEvent' && $filter->($sample)) {
      $last = $i;
    }
  }

  my $result = [];
  for (my $i = 0; $i < $last; $i++) {
    my $sample = $samples->[$i];
    if ($sample->{event} eq 'timerEvent') {
      push @$result, $sample;
    }
  }

  return $result;
}

sub _tune {
  my ($self, $samples, $params, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  my $bias_scale = delete($options{'bias-scale'}) // 20;

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    foreach my $param (@$params) {
      $self->{$param} = shift;
    }
    $self->initialize;

    my $sum2 = 0;

    foreach my $sample (@$samples) {
      if (!exists($sample->{event}) || $sample->{event} eq 'timerEvent') {
        $self->predictTemperature($sample);

        my $error = $sample->{$prediction} - $sample->{$expected};
        my $err2 = $error * $error;

        if ($options{bias}) {
          my $rel_temp = $sample->{$expected} - $sample->{ambient};
          my $bias = floor($rel_temp / $bias_scale);
          if ($bias < 1) {
              $bias = 1;
          }
          $err2 = $err2 * $bias;
        }
          
        $sum2 += $err2;
      }
    }

    return $sum2;
  };

  my @values = minimumSearch($fn, $bounds, %options);
  my $tuned = {};

  foreach my $param (@$params) {
    my $val = shift @values;
    $self->{$param} = $val;
    $tuned->{$param} = $val;
  }
  $self->initialize;

  $tuned->{package} = ref($self);

  return $tuned;
}

sub description {
  my ($self) = @_;

  return ref($self);
}

sub setLogger {
  my ($self, $logger) = @_;

  $self->{'logger'} = $logger;

  $self->info('Using Predictor: '. $self->description);
}

sub info {
  my $self = shift;

  $self->{logger}->info(@_) if $self->{logger};
}

sub warning {
  my $self = shift;

  $self->{logger}->warning(@_) if $self->{logger};
}

sub error {
  my $self = shift;

  $self->{logger}->error(@_) if $self->{logger};
}

sub debug {
  my $self = shift;

  $self->{logger}->debug(@_) if $self->{logger};
}

1;