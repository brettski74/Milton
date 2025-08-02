package PowerSupplyControl::Math::LowPassFilter;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);

sub new {
  my ($class, %args) = @_;
  my $self = { %args };

  croak "tau is a mandatory parameter for a low pass filter." if !defined $self->{tau};
  croak "period is a mandatory parameter for a low pass filter." if !defined $self->{period};
  croak "period must be positive for a low pass filter." if $self->{period} <= 0;
  croak "tau must be non-negative for a low pass filter." if $self->{tau} < 0;

  $self->{alpha} = $self->{period} / ($self->{period} + $self->{tau});

  return bless $self, $class;
}

sub next {
  my ($self, $value, $tau) = @_;

  my $alpha;
  if (defined $tau) {
    $self->{tau} = $tau;
    $alpha = $self->{alpha} = $self->{period} / ($self->{period} + $self->{tau});
  } else {
    $alpha = $self->{alpha};
  }

  my $last = $self->{value} // $value;

  return $self->{value} = $alpha * $value + (1-$alpha) * $last;
}

sub last {
  my ($self) = @_;
  return $self->{value};
}

1;
