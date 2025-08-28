package PowerSupplyControl::Predictor::DoubleLPFPower;

use base 'PowerSupplyControl::Predictor::DoubleLPF';

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{'power-tau'} //= 60;
  $self->{'power-gain'} //= 2.47;
  $self->{'power-gradient'} //= 0;

  return $self;
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $period = $status->{period};
  my $power = $status->{power};
  my $ambient = $status->{ambient};
  my $temperature = $status->{temperature};

  if (defined $self->{'last-heating-element'}) {
    my $alpha = $period / ($period + $self->{'power-tau'});
    my $rel_temp = $temperature - $ambient;
    my $gain = $self->{'power-gain'} + $self->{'power-gradient'} * $rel_temp;
    my $ss_temp = $ambient + $power * $gain;
    $status->{'predict-heating-element'} = $self->{'last-heating-element'} * (1-$alpha) + $alpha * $ss_temp;
  } else {
    $status->{'predict-heating-element'} = $temperature // $ambient;
  }

  $self->{'last-heating-element'} = $status->{'predict-heating-element'};
  
  if (!exists $status->{'device-temperature'}) {
    $status->{'device-temperature'} = $status->{'predict-heating-element'};
  }

  return $self->SUPER::predictTemperature($status);
}

sub predictPower {
  my ($self, $status) = @_;
  my $target_temp = $status->{'then-temperature'};
  my $temperature = $status->{'predict-temperature'};
  my $hotplate_now = $status->{temperature};
  my $ambient = $status->{ambient};
  my $period = $status->{period};
  my $inner_alpha = $period / ($period + $self->{'inner-tau'});
  my $power_alpha = $period / ($period + $self->{'power-tau'});

  # Need pre_pre, but requires knowing the required hotplate temperature. Approximate it by
  # applying the delta between now and then to the current hotplate temperature.
  my $pre_pre = $hotplate_now + ($target_temp - $temperature);
  my $outer_tau = $self->{'outer-gradient'} * $pre_pre + $self->{'outer-offset'};
  my $outer_alpha = $period / ($period + $self->{'outer-tau'});

  # Required hotplate temperature back-calculated from the predictor parameters
  my $hotplate_then = ($target_temp - $outer_alpha * $ambient) / (1 - $outer_alpha) / $inner_alpha - (1 - $inner_alpha) * $temperature / $inner_alpha;

  # Now we can calculate the required power
  my $power = ($hotplate_then - $hotplate_now * (1 - $power_alpha) - $power_alpha * $ambient) / $power_alpha / $self->{'power-gain'};

  return $power;
}

  
  # First predict the hotplate temperature required to reach the target temperature.
  # Need inner and outer loop alphas.
  my $inner_alpha = $status->{period} / ($status->{period} + $self->{'inner-tau'});
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-heating-element'};

  return $self->SUPER::initialize;
}

sub description {
  my ($self) = @_;
  return sprintf('DoubleLPFPower(inner-tau=%.3f, outer-offset=%.3f, outer-gradient=%.3f, power-tau=%.3f, power-gain=%.3f,power-gradient=%.3f)',
                 $self->{'inner-tau'}, $self->{'outer-offset'}, $self->{'outer-gradient'},
                 $self->{'power-tau'}, $self->{'power-gain'}, $self->{'power-gradient'});
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $tuned = $self->SUPER::tune($samples, %args);

  my $ptuned = $self->_tune($samples
                            , [ 'power-tau', 'power-gain', 'power-gradient' ]
                            , [ [ 0, 1000 ], [ 0, 10 ], [ -5, 5 ] ]
                            , 'lower-constraint' => [ 0, 0, undef ]
                            , threshold => [ 0.01, 0.001, 0.001 ]
                            , steps => [ 32, 64, 32 ]
                            , bias => 2
                            , depth => 512
                            , prediction => 'predict-heating-element'
                            , expected => 'temperature'
                            , %args
                            );

  return { %$tuned, %$ptuned };
}

1;