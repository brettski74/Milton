package PowerSupplyControl::Predictor;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class, %options) = @_;

  my $self = { %options };

  bless $self, $class;

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

1;