package PowerSupplyControl::Predictor;

use strict;
use warnings qw(all -uninitialized);

use PowerSupplyControl::Math::Util qw(minimumSearch);

sub new {
  my ($class, %options) = @_;

  my $self = { %options };

  bless $self, $class;

  $self->initialize;

  return $self;
}

sub setPredictedTemperature {
  my ($self, $temperature) = @_;

  $self->{'predict-temperature'} = $temperature;
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
  $self->{'predict-temperature'} = $prediction;
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

sub _tune {
  my ($self, $samples, $params, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  my $time_cut_off = $self->{'time-cut-off'} // 240;
  my $temperature_cut_off = $self->{'temperature-cut-off'} // 120;

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

        # Avoid using the long cool-down tail samples. We don't care about them and want the
        # prediction to best match the important/active sections of the profile.
        if ($sample->{now} < $time_cut_off || $sample->{$expected} > $temperature_cut_off) {
          my $error = $sample->{$prediction} - $sample->{$expected};
          my $err2 = $error * $error;

          if ($options{bias}) {
            $err2 = $err2 * ($sample->{$expected} - $sample->{ambient});
          }
          
          $sum2 += $err2;
        }
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
  my ($self, $message) = @_;

  $self->{'logger'}->info($message) if $self->{'logger'};
}

sub warning {
  my ($self, $message) = @_;

  $self->{'logger'}->warning($message) if $self->{'logger'};
}

sub error {
  my ($self, $message) = @_;

  $self->{'logger'}->error($message) if $self->{'logger'};
}

sub debug {
  my ($self, $level, $message) = @_;
  print "Log level: $level\n";

  $self->{'logger'}->debug($level, $message) if $self->{'logger'};
}

1;