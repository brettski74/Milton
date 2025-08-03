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

sub _tune2D {
  my ($self, $samples, $param1, $param2, $limits, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    my ($p1, $p2) = @_;

    # Remove any saved state
    $self->initialize;

    $self->{$param1} = $p1;
    $self->{$param2} = $p2;

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

  my ($p1, $p2) = minimumSearch($fn, $limits->[0], $limits->[1], %options);

  $self->{$param1} = $p1;
  $self->{$param2} = $p2;

  return { $param1 => $p1, $param2 => $p2 };
}

sub _tune3D {
  my ($self, $samples, $param1, $param2, $param3, $limits, %options) = @_;

  my $prediction = $options{prediction} // 'predict-temperature';
  my $expected = $options{expected} // 'device-temperature';

  delete $options{prediction};
  delete $options{expected};

  my $fn = sub {
    my ($p1, $p2, $p3) = @_;

    $self->initialize;

    $self->{$param1} = $p1;
    $self->{$param2} = $p2;
    $self->{$param3} = $p3;

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

  my ($p1, $p2, $p3) = minimumSearch($fn, $limits, %options);

  $self->{$param1} = $p1;
  $self->{$param2} = $p2;
  $self->{$param3} = $p3;

  return { $param1 => $p1, $param2 => $p2, $param3 => $p3 };
}

1;