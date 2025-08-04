package PowerSupplyControl::Math::LowPassFilter;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);

sub new {
  my ($class, %args) = @_;
  my $self = { %args };

  bless $self, $class;
  croak "period must be positive for a low pass filter." if $self->{period} <= 0;

  $self->setTau($self->{tau}, $self->{period});

  return $self;
}

sub _initialize {
  my ($self, %args) = @_;

  if (exists $args{tau}) {
    if (exists $args{period}) {
      $self->setTau($args{tau}, $args{period});
    } else {
      $self->setTau($args{tau});
    }
  } elsif (exists $args{period}) {
    $self->setPeriod($args{period});
  }
}

sub next {
  my ($self, $value, %args) = @_;

  $self->_initialize(%args);

  my $alpha = $self->{alpha};

  my $last = $self->{value};
  if (defined $last) {
    return $self->{value} = $alpha * $value + (1-$alpha) * $last;
  }
  return $self->{value} = $value;
}

sub last {
  my ($self) = @_;
  return $self->{value};
}

sub reset {
  my ($self, $value, %args) = @_;

  $self->{value} = $value;

  $self->_initialize(%args) if @_ > 2;

  return $value;
}

sub setTau {
  my ($self, $tau, $period) = @_;

  if ($tau < 0 || !defined $tau) {
    croak "tau must be non-negative for a low pass filter.";
  }

  $self->{tau} = $tau;
  if (@_ > 2) {
    $self->setPeriod($period);
  } else {
    $self->{alpha} = $self->{period} / ($self->{period} + $self->{tau});
  }
}
sub setPeriod {
  my ($self, $period) = @_;

  if ($period <= 0) {
    croak "period must be positive for a low pass filter.";
  }

  $self->{period} = $period;
  $self->{alpha} = $self->{period} / ($self->{period} + $self->{tau});
}

sub period {
  my ($self) = @_;
  return $self->{period};
}

sub tau {
  my ($self) = @_;
  return $self->{tau};
}

sub tune {
  my ($self, $samples, $input_key, $output_key, $threshold, $upper_bound) = @_;

  $upper_bound //= 500;
  $threshold //= 0.001;

  my $fn = sub {
    my ($tau) = @_;
    $self->setTau($tau);

    delete $self->{value};
    my $sum2 = 0;

    foreach my $sample (@$samples) {
      my $input = $sample->{$input_key};
      my $output = $self->next($input);
      my $error = $output - $sample->{$output_key};
      $sum2 += $error * $error;
    }

    return $sum2;
  };

  my $tau = minimumSearch($fn, [ [ 0, $upper_bound ] ]);

  $self->setTau($tau);

  return { tau => $tau };
}

1;
