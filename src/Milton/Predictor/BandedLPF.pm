package Milton::Predictor::BandedLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Predictor);
use Milton::Math::PiecewiseLinear;

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  if (!exists $self->{bands}) {
    $self->{bands} = [ { temperature => 25 , 'inner-tau' => 3.357 , 'outer-tau' => 2000 } ];
  }
  $self->{'inner-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'inner-tau', @{$self->{bands}});
  $self->{'outer-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'outer-tau', @{$self->{bands}});
  $self->{'power-tau'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'power-tau', @{$self->{bands}});
  $self->{'power-gain'} = Milton::Math::PiecewiseLinear->new->addHashPoints('temperature', 'power-gain', @{$self->{bands}});

  if ($self->{'power-tau'}->length < 1) {
    delete $self->{'power-tau'};
  }
  if ($self->{'power-gain'}->length < 1) {
    delete $self->{'power-gain'};
  }

  return $self;
}

sub description {
  my ($self) = @_;

  if (!exists $self->{description}) {
    my ($itmin, $itmax);
    my ($otmin, $otmax);
    my ($ptmin, $ptmax);
    my ($pgmin, $pgmax);

    foreach my $band (@{$self->{bands}}) {
      $itmin = $band->{'inner-tau'} if !defined $itmin || $band->{'inner-tau'} < $itmin;
      $itmax = $band->{'inner-tau'} if !defined $itmax || $band->{'inner-tau'} > $itmax;
      $otmin = $band->{'outer-tau'} if !defined $otmin || $band->{'outer-tau'} < $otmin;
      $otmax = $band->{'outer-tau'} if !defined $otmax || $band->{'outer-tau'} > $otmax;
      $ptmin = $band->{'power-tau'} if !defined $ptmin || $band->{'power-tau'} < $ptmin;
      $ptmax = $band->{'power-tau'} if !defined $ptmax || $band->{'power-tau'} > $ptmax;
      $pgmin = $band->{'power-gain'} if !defined $pgmin || $band->{'power-gain'} < $pgmin;
      $pgmax = $band->{'power-gain'} if !defined $pgmax || $band->{'power-gain'} > $pgmax;
    }

    $self->{description} = sprintf('BandedLPF (inner-tau: [%.3f-%.3f], outer-tau: [%.3f-%.3f], power-tau: [%.3f-%.3f], power-gain: [%.3f-%.3f])'
                                 , $itmin, $itmax, $otmin, $otmax, $ptmin, $ptmax, $pgmin, $pgmax
                                 );
  }

  return $self->{description};
}

sub setInterface {
  my ($self, $interface) = @_;
  $self->{interface} = $interface;
}

sub _predictHeatingElement {
  my ($self, $status, $last_heating_element) = @_;

  my $period = $status->{period};
  my $power = $status->{power};
  my $ambient = $status->{ambient};
  my $temperature = $last_heating_element;
  my $reference_temperature = $temperature // $ambient;
  my $prediction;

  if (defined $temperature) {
    my $tau = $self->{'power-tau'}->estimate($reference_temperature);
    my $alpha = $period / ($period + $tau);
    my $rel_temp = $temperature - $ambient;

    my $gain = $self->{'power-gain'}->estimate($reference_temperature);
    my $ss_temp = $ambient + $power * $gain;
    $prediction = $temperature * (1-$alpha) + $alpha * $ss_temp;
  } else {
    $prediction = $status->{temperature} // $ambient;
  }

  return $prediction;
}

sub predictHeatingElement {
  my ($self, $status) = @_;

  if (!exists($self->{'power-tau'}) || !exists($self->{'power-gain'})) {
    return;
  }

  my $prediction = $self->_predictHeatingElement($status, $self->{'last-heating-element'});
  $self->{'last-heating-element'} = $prediction;
  $status->{'predict-heating-element'} = $prediction;

  if (!defined $status->{temperature}) {
    $status->{temperature} = $prediction;
  } elsif (!exists $status->{'device-temperature'}) {
    $status->{'device-temperature'} = $prediction;
  }

  return $prediction;
}

sub _calculateTemperatureForPower {
  my ($self, $status, $power, $last_prediction, $last_heating_element) = @_;

  delete $status->{temperature};
  $status->{power} = $power;

  $status->{temperature} = $self->_predictHeatingElement($status, $last_heating_element);
  return $self->_predictTemperature($status, $last_prediction);
}

sub predictPower {
  my ($self, $status) = @_;

  if (!exists($self->{'power-tau'}) || !exists($self->{'power-gain'})) {
    return 0;
  }

  # Set up state for predicting temperature for a given power level
  my $target_temp = $status->{'anticipate-temperature'} // $status->{'then-temperature'};
  my $last_prediction = $status->{'predict-temperature'};
  my $last_heating_element = $status->{'temperature'};
  my $next_status = { ambient => $status->{ambient}
                    , period => $status->{'anticipate-period'} // $status->{period}
                    };

  # Start with a high guess and a low guess
  my ($plo, $phi) = $self->{interface}->getPowerLimits();
  my $thi = $self->_calculateTemperatureForPower($next_status, $phi, $last_prediction, $last_heating_element);

  # If maximum power isn't going to get us up there, then we're done
  if ($thi < $target_temp) {
    return $phi;
  }

  my $tlo = $self->_calculateTemperatureForPower($next_status, $plo, $last_prediction, $last_heating_element);
  # If minimum power isn't going to get us down there, then we're done
  if ($tlo > $target_temp) {
    return $plo;
  }

  # Otherwise, we need to binary search between the two
  while ($phi - $plo > 1) {
    my $p = ($plo + $phi) / 2;
    my $t = $self->_calculateTemperatureForPower($next_status, $p, $last_prediction, $last_heating_element);

    if ($t < $target_temp) {
      $plo = $p;
      $tlo = $t;
    } elsif ($t == $target_temp) {
      return $p;
    } else  {
      $phi = $p;
      $thi = $t;
    }
  }

  # Linear interpolate between the two
  return $plo + ($phi - $plo) * ($target_temp - $tlo) / ($thi - $tlo);
}

sub _predictTemperature {
  my ($self, $status, $last_prediction) = @_;

  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $period = $status->{period};

    # Pull hotplate temperature towards heating element temperature
    my $inner_tau = $self->{'inner-tau'}->estimate($last_prediction);
    my $alpha = $period / ($period + $inner_tau);
    my $pre_pre = $status->{temperature} * $alpha + (1-$alpha) * $last_prediction;

    # And pull it back down to ambient temperature
    my $tau = $self->{'outer-tau'}->estimate($pre_pre);
    $alpha = $period / ($period + $tau);
    $prediction = $ambient * $alpha + (1-$alpha) * $pre_pre;
  } else {
    $prediction = $status->{temperature};
  }

  return $prediction;
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $prediction = $self->_predictTemperature($status, $self->{'last-prediction'});

  $self->{'last-prediction'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-prediction'};

  foreach my $key (qw(inner-tau outer-tau power-tau power-gain)) {
    if (!ref $self->{$key}) {
      $self->{$key} = Milton::Math::PiecewiseLinear->new->addPoint(25, $self->{$key});
    }
  }
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $parallel = $self->{tuning}->{parallel} // 1;

  my $bands = $self->buildSampleBands($samples);
  my $tuned = [];

  foreach my $band (@$bands) {
    $self->info("Band Centre: $band->{centre}, sample count: ". scalar(@{$band->{samples}}));

    my $t = $self->_tune($band->{samples}
                       , [ 'inner-tau', 'outer-tau' ]
                       , [ [ 0, 30 ], [ 100, 4000 ] ]
                       , 'lower-constraint' => [ 0, 0 ]
                       , threshold => [ 0.001, 0.001 ]
                       , steps => [ 80, 80 ]
                       , bias => 1
                       , depth => 150
                       , %args
                       );
    my $p = $self->_tune($band->{samples}
                       , [ 'power-tau', 'power-gain' ]
                       , [ [ 0.1, 200 ], [ 0.1, 20 ] ]
                       , 'lower-constraint' => [ 0.1, 0.1 ]
                       , threshold => [ 0.001, 0.001 ]
                       , steps => [ 80, 80 ]
                       , bias => 1
                       , depth => 150
                       , prediction => 'predict-heating-element'
                       , expected => 'temperature'
                       , %args
                       );

    # Don't need package name here
    delete $t->{package};
    delete $p->{package};
    my $temperature = $band->{centre} // (($band->{min} + $band->{max})/2);

    push @$tuned, { temperature => $temperature
                  , %$t
                  , %$p
                  };
  }

  # Flatten out the bottom end
  my $t = { %{$tuned->[0]} };
  $t->{temperature} = 25;
  unshift @$tuned, $t;
  
  return { package => ref($self), bands => $tuned };
}

1;