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
  my ($self, $status) = @_;

  $self->{'predict-temperature'} = $status->{temperature};
  $status->{'predict-temperature'} = $status->{temperature};

  return $status->{temperature};
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

sub setLogger {
  my ($self, $logger) = @_;

  $self->{'logger'} = $logger;

  $self->info('Using Predictor: '. ref($self));
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