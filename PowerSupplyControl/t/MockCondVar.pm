package PowerSupplyControl::t::MockCondVar;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class) = @_;

  my $self = {
    value => 0,
  };
  bless $self, $class;

  return $self;
}

sub send {
  my ($self) = @_;

  $self->{sent}++;
}

sub recv {
  return;
}

1;