package HP::PiecewiseLinear;

=head1 CONSTRUCTOR

=head2 new

Create a new PiecewiseLinear estimator.

=cut

sub new {
  my $class = shift;

  my $self = [];

  bless $self, $class;

  return $self;
}

=head2 addPoint($x, $y {, $x, $y})

Add one or more data points to this piecewise linear estimator.

=over

=item $x

The x value for a data point.

=item $y

The y value for a data point.

=item Return Value

Returns the PiecewiseLinear estimator, so that method calls may be chained.

=cut

sub addPoint {
  my $self = shift;
  my @new = ();

  while (@_) {
    my $x = shift;
    my $y = shift;

    push @new, [ $x, $y ];
  }

  @$self = sort { $a->[0] <=> $b->[0] } (@$self, @new);

  return $self;
}

=head2 estimate($x)

Return the interpolated/extrapolated Y value for the specified X value.

=over

=item $x

The X value for which a corresponding Y value is required.

=item Return Value

The estimated Y value for the specified X value.

=back

=cut

sub estimate {
  my ($self, $x) = @_;

  # Handle empty estimator
  return undef if @$self == 0;

  # Handle single point
  if (@$self == 1) {
    return $self->[0]->[1];
  }

  # Handle extrapolation below range
  if ($x < $self->[0]->[0]) {
    return $self->estimateFromPoints($x, @{$self->[0]}, @{$self->[1]});
  }

  # Handle extrapolation above range
  if ($x > $self->[-1]->[0]) {
    return $self->estimateFromPoints($x, @{$self->[-2]}, @{$self->[-1]});
  }

  # Handle exact matches
  for my $point (@$self) {
    if ($x == $point->[0]) {
      return $point->[1];
    }
  }

  # Find the segment for interpolation
  my $idx;
  for ($idx = 1; $idx < @$self; $idx++) {
    last if ($x < $self->[$idx]->[0]);
  }

  return $self->estimateFromPoints($x, @{$self->[$idx-1]}, @{$self->[$idx]});
}

sub estimateFromPoints {
  my ($self, $x, $xlo, $ylo, $xhi, $yhi) = @_;

  return ($ylo * ($xhi - $x) + $yhi * ($x - $xlo)) / ($xhi - $xlo);
}

sub length {
  my ($self) = @_;

  return scalar(@$self);
}

1;
