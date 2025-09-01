package Milton::Predictor::DoubleLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Predictor);

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{'inner-tau'} //= 27;
  $self->{'outer-gradient'} //= 0;
  $self->{'outer-offset'} //= 300;

  return $self;
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $last_prediction = $self->{'last-prediction'};
  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $period = $status->{period};

    # Pull hotplate temperature towards heating element temperature
    my $alpha = $period / ($period + $self->{'inner-tau'});
    my $pre_pre = $status->{temperature} * $alpha + (1-$alpha) * $last_prediction;

    # And pull it back down to ambient temperature
    my $tau = $self->{'outer-gradient'} * $pre_pre + $self->{'outer-offset'};
    $alpha = $period / ($period + $tau);
    $prediction = $ambient * $alpha + (1-$alpha) * $pre_pre;
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

sub description {
  my ($self) = @_;
  return sprintf('DoubleLPF(inner-tau=%.3f, outer-offset=%.3f, outer-gradient=%.3f)',
                 $self->{'inner-tau'}, $self->{'outer-offset'}, $self->{'outer-gradient'});
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $parallel = $self->{tuning}->{parallel} // 1;

  my $filtered = $self->filterSamples($samples);

  my $tuned = $self->_tune($filtered
                           , [ 'inner-tau', 'outer-offset', 'outer-gradient' ]
                           , [ [ 0, 30 ], [ 200, 4000 ], [ -20, 0 ] ]
                           , 'lower-constraint' => [ 0, 0, undef ]
                           , threshold => [ 0.001, 0.01, 0.0001 ]
                           , steps => [ 32, 64, 32 ]
                           , bias => 1
                           , depth => 512
                           , %args
                           );
  
  return $tuned;
}

1;