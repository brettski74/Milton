package Milton::Predictor::DoubleLPFPower;

use base 'Milton::Predictor::DoubleLPF';

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{'power-tau'} //= 60;
  
  my $power_gain = Milton::Math::PiecewiseLinear->new;
  my $power_tau  = Milton::Math::PiecewiseLinear->new;

  if (exists $self->{power} && ref($self->{power})) {
    $power_gain->addHashPoints('temperature', 'gain', @{$self->{power}});
    $power_tau->addHashPoints('temperature', 'tau', @{$self->{power}});
  }

  if ($power_gain->length <= 0) {
    $power_gain->addPoint(25, 2.8);
  }

  if ($power_tau->length <= 0) {
    $power_tau->addPoint(25, 90);
  }

  $self->{'power-gain'} = $power_gain;
  $self->{'power-tau'} = $power_tau;

  return $self;
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $period = $status->{period};
  my $power = $status->{power};
  my $ambient = $status->{ambient};
  my $temperature = $status->{temperature};
  my $last_heating_element = $self->{'last-heating-element'};
  my $reference_temperature = $temperature // $last_heating_element // $ambient;

  if (defined $last_heating_element) {
    my $tau = $self->{'power-tau'}->estimate($reference_temperature);
    my $alpha = $period / ($period + $tau);
    my $rel_temp;
    if (!defined $temperature) {
      $rel_temp = $last_heating_element - $ambient;
    } else {
      $rel_temp = $temperature - $ambient;
    }

    my $gain = $self->{'power-gain'}->estimate($reference_temperature);
    my $ss_temp = $ambient + $power * $gain;
    $status->{'predict-heating-element'} = $self->{'last-heating-element'} * (1-$alpha) + $alpha * $ss_temp;
  } else {
    $status->{'predict-heating-element'} = $reference_temperature;
  }

  $self->{'last-heating-element'} = $status->{'predict-heating-element'};
  if (!defined $status->{temperature}) {
    $status->{temperature} = $status->{'predict-heating-element'};
  } elsif (!exists $status->{'device-temperature'}) {
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
  my $power_tau = $self->{'power-tau'}->estimate($hotplate_now);
  my $power_alpha = $period / ($period + $power_tau);

  # Need pre_pre, but requires knowing the required hotplate temperature. Approximate it by
  # applying the delta between now and then to the current hotplate temperature.
  my $pre_pre = $hotplate_now + ($target_temp - $temperature);
  my $outer_tau = $self->{'outer-gradient'} * $pre_pre + $self->{'outer-offset'};
  my $outer_alpha = $period / ($period + $self->{'outer-tau'});

  # Required hotplate temperature back-calculated from the predictor parameters
  my $hotplate_then = ($target_temp - $outer_alpha * $ambient) / (1 - $outer_alpha) / $inner_alpha - (1 - $inner_alpha) * $temperature / $inner_alpha;

  # Now we can calculate the required power
  my $power_gain = $self->{'power-gain'}->estimate($hotplate_now);
  my $power = ($hotplate_then - $hotplate_now * (1 - $power_alpha) - $power_alpha * $ambient) / $power_alpha / $power_gain;

  return $power;
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-heating-element'};

  # Tuning will just stick numbers in here, we need to make those into estimators so that power prediction doesn't break!
  if (! ref $self->{'power-tau'}) {
    $self->{'power-tau'} = Milton::Math::PiecewiseLinear->new->addPoint(25, $self->{'power-tau'});
  }

  if (! ref $self->{'power-gain'}) {
    $self->{'power-gain'} = Milton::Math::PiecewiseLinear->new->addPoint(25, $self->{'power-gain'});
  }
}

sub description {
  my ($self) = @_;
  return sprintf('DoubleLPFPower(inner-tau=%.3f, outer-offset=%.3f, outer-gradient=%.3f, power-tau=%.3f, power-gain=%.3f,power-gradient=%.3f)',
                 $self->{'inner-tau'}, $self->{'outer-offset'}, $self->{'outer-gradient'},
                 $self->{'power-tau'}, $self->{'power-gain'}, $self->{'power-gradient'});
}

sub _tunePower {
  my ($self, $samples, %options) = @_;

  # Build a temperature dependent estimator for power gain
  my $subs = $self->_buildSubHistories($samples);

  my $tuned = [];
  foreach my $sub (@$subs) {
    my $t = $self->_tune($sub->{samples}
                       , [ 'power-tau', 'power-gain' ]
                       , [ [ 0, 1000 ], [ 0, 10 ] ]
                       , 'lower-constraint' => [ 0, 0 ]
                       , threshold => [ 0.01, 0.001 ]
                       , steps => [ 100, 100 ]
                       , bias => 1
                       , depth => 100
                       , prediction => 'predict-heating-element'
                       , expected => 'temperature'
                       , %options
                       );

    # flatten the curves at the bottom
    if (! @$tuned) {
      push @$tuned, { temperature => 25, %$t };
    }

    $t->{temperature} = ($sub->{min} + $sub->{max}) / 2;

    push @$tuned, $t;
  }

  return $tuned;
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $tuned = $self->SUPER::tune($samples, %args);

  $tuned->{power} = $self->_tunePower($samples, %args);

  return $tuned;
}

1;