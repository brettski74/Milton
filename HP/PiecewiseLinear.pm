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

=head2 estimator($x)

Return the interpolated/extrapolated Y value for the specified X value.

=over

=item $x

The X value for which a corresponding Y value is required.

=item Return Value

The estimated Y value for the specified X value.

=back

=cut

sub estimator {
  my ($self, $x) = @_;

  my $idx;
  for ($idx=1; $idx < $#$self; $idx++) {
    last if ($x < $self->[$idx]->[0]);
  }

  # my ($xlo, $ylo) = @{$self->[$idx-1]};
  # my ($xhi, $yhi) = @{$self->[$idx]};

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
