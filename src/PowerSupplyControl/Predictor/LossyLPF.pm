package PowerSupplyControl::Predictor::LossyLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(PowerSupplyControl::Predictor);

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{tau} //= 27;
  $self->{'loss-factor'} //= 0.925;

  return $self;
}

sub description {
  my ($self) = @_;
  return sprintf('LossyLPF(tau=%.3f, loss-factor=%.3f)', $self->{tau}, $self->{'loss-factor'});
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $last_prediction = $self->{'last-prediction'};
  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $alpha = $status->{period} / ($status->{period} + $self->{tau});
    my $rel_temperature = ($status->{temperature} - $ambient) * $self->{'loss-factor'};
    $prediction = $ambient + $rel_temperature * $alpha + (1-$alpha) * ($last_prediction - $ambient);
  } else {
    $prediction = $status->{temperature};
  }

  $self->{'last-prediction'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-prediction'};
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $parallel = $self->{tuning}->{parallel} // 1;

  my $tuned = $self->_tune($samples
                           , [ 'tau', 'loss-factor' ]
                           , [ [ 0, 100 ], [ 0.8, 1 ] ]
                           , 'lower-constraint' => [ 0, 0.8 ]
                           , 'upper-constraint' => [ undef, 1 ]
                           , threshold => 0.001
                           , %args
                           );
  
  return $tuned;
}

1;