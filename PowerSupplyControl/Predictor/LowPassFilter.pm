package PowerSupplyControl::Predictor::LowPassFilter;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Predictor);

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{tau} //= 25;

  return $self;
}

sub predictTemperature {
  my ($self, $status) = @_;

  if (exists $self->{'predict-temperature'}) {
    my $alpha = $status->{period} / ($status->{period} + $self->{tau});

    $self->{'predict-temperature'} = $status->{temperature} * $alpha + (1-$alpha) * $self->{'predict-temperature'};
    $status->{'predict-temperature'} = $self->{'predict-temperature'};

    return $self->{'predict-temperature'};
  }

  $self->{'predict-temperature'} = $status->{temperature};
  $status->{'predict-temperature'} = $status->{temperature};

  return $status->{temperature};
}

sub tune {
  my ($self, $samples) = @_;

  my $saved_tau = $self->{tau};
  my $saved_predict_temperature = $self->{'predict-temperature'};
  my $delay_threshold_temp = $self->{'delay-threshold-temp'} // 0;

  my $fn = sub {
    my ($tau) = @_;
    $self->{tau} = $tau;
    delete $self->{'predict-temperature'};

    my $sum_error2 = 0;
    foreach my $sample (@$samples) {
      if ($sample->{temperature} > $delay_threshold_temp) {
        my $error = $sample->{temperature} - $self->predictTemperature($sample);
        $sum_error2 += $error * $error;
      }
    }

    return $sum_error2;
  };

  my $tau = minimumSearch($fn, 1, 100, lower_constrained => 1);

  $self->{tau} = $saved_tau;
  $self->{'predict-temperature'} = $saved_predict_temperature;

  return { tau => $tau };
}

1;