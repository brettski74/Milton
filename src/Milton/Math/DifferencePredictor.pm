package Milton::Math::DifferencePredictor;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class, $order) = @_;

  my $self = [ map { undef } 1 .. $order+1 ]; 

  bless $self, $class;

  return $self;
}

sub predict {
  my ($self, $ahead) = @_;

  my $rc = $self->[0];
  if (defined $rc) {
    my @diffs = @{$self}[1 .. $#$self];

    while ($ahead > 0) {
      for (my $i=$#diffs-1; $i>=0; $i--) {
        $diffs[$i] += $diffs[$i+1];
      }
      $rc += $diffs[0];
      $ahead--;
    }
  }

  return $rc;
}

sub next {
  my ($self, $value) = @_;
  
  my @last = @$self;
  $self->[0] = $value;

  for (my $i=0; $i<$#last;$i++) {
    $self->[$i+1] = $self->[$i] - $last[$i];
  }

  return $self;
}

sub last {
  my ($self, $behind) = @_;

  return if $behind > $#$self;
    
  my $rc = $self->[0];
  if (defined $rc) {
    my @diffs = @{$self}[1 .. $#$self];
    while ($behind > 0) {
      $rc -= $diffs[0];
      last if --$behind <= 0;

      for (my $i=$#diffs-1; $i>=0; $i--) {
        $diffs[$i] -= $diffs[$i+1];
      }
    }
  }

  return $rc;
}

sub difference {
  my ($self, $order) = @_;

  return if ($order < 1 || $order > $#$self);

  return $self->[$order];
}

1;