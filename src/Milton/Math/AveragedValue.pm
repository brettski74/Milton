package Milton::Math::AveragedValue;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class) = @_;

  my $self = [ 0, 0 ];
  bless $self, $class;

  return $self;
}

sub value {
  my ($self) = @_;

  return $self->[0] / $self->[1];
}

sub add {
  my ($self, $value) = @_;

  $self->[0] += $value;
  $self->[1]++;

  return $self;
}

1;