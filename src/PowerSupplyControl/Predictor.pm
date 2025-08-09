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

sub _tune1D {
  my ($self, $samples, $param, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    my ($p) = @_;

    $self->{$param} = $p;

    # Remove any saved state and apply updated parameters
    $self->initialize;

    my $sum2 = 0;

    foreach my $sample (@$samples) {
      if (!exists($sample->{event}) || $sample->{event} eq 'timerEvent') {
        $self->predictTemperature($sample);
        my $error = $sample->{$prediction} - $sample->{$expected};
        $sum2 += $error * $error;
      }
    }

    return $sum2;
  };

  my $p = minimumSearch($fn, $bounds, %options);

  $self->{$param} = $p;
  $self->initialize;

  return { $param => $p };
}

sub _tune2D {
  my ($self, $samples, $param1, $param2, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    my ($p1, $p2) = @_;

    $self->{$param1} = $p1;
    $self->{$param2} = $p2;

    # Remove any saved state and apply updated parameters
    $self->initialize;

    my $sum2 = 0;

    foreach my $sample (@$samples) {
      if (!exists($sample->{event}) || $sample->{event} eq 'timerEvent') {
        $self->predictTemperature($sample);
        my $error = $sample->{$prediction} - $sample->{$expected};
        $sum2 += $error * $error;
      }
    }

    return $sum2;
  };

  my ($p1, $p2) = minimumSearch($fn, $bounds, %options);

  $self->{$param1} = $p1;
  $self->{$param2} = $p2;
  $self->initialize;

  return { $param1 => $p1, $param2 => $p2 };
}

sub _tune {
  my ($self, $samples, $params, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

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
          $err2 = $err2 * ($sample->{$expected} - $sample->{ambient});
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

  return $tuned;
}

sub _tune3D {
  my ($self, $samples, $param1, $param2, $param3, $bounds, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    my ($p1, $p2, $p3) = @_;

    $self->{$param1} = $p1;
    $self->{$param2} = $p2;
    $self->{$param3} = $p3;

    # Remove any saved state and apply updated parameters
    $self->initialize;

    my $sum2 = 0;

    foreach my $sample (@$samples) {
      if (!exists($sample->{event}) || $sample->{event} eq 'timerEvent') {
        $self->predictTemperature($sample);
        my $error = $sample->{$prediction} - $sample->{$expected};
        $sum2 += $error * $error;
      }
    }

    return $sum2;
  };

  my ($p1, $p2, $p3) = minimumSearch($fn, $bounds, %options);

  $self->{$param1} = $p1;
  $self->{$param2} = $p2;
  $self->{$param3} = $p3;
  $self->initialize;

  return { $param1 => $p1, $param2 => $p2, $param3 => $p3 };
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

  $self->{'logger'}->debug($level, $message) if $self->{'logger'};
}

1;