package PowerSupplyControl::Math::LinearSigmoidWeight;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class, $gradient, $offset) = @_;

  my $self = [ $gradient, $offset ];

  return bless $self, $class;
}

sub initialize {
  my ($self, $gradient, $offset) = @_;

  $self->[0] = $gradient;
  $self->[1] = $offset;
}

sub weight {
  my ($self, $value) = @_;

  my $x = $self->[0] * $value + $self->[1];

  return 1 / (1 + exp(-$x));
}

1;