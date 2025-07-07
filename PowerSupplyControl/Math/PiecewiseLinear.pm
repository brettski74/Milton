package PowerSupplyControl::Math::PiecewiseLinear;

=head1 CONSTRUCTOR

=head2 new

Create a new PiecewiseLinear estimator.

=cut

sub new {
  my $class = shift;

  my $self = [];

  bless $self, $class;

  $self->addPoint(@_) if @_;

  return $self;
}

=head2 addNamedPoint($x, $y, $name {, $x, $y, $name})

Add a data point to this piecewise linear estimator with a name.

=over

=item $x

The x value for a data point.

=item $y

The y value for a data point.

=item $name

The name for a data point.

=item Return Value

Returns the PiecewiseLinear estimator, so that method calls may be chained.

=back

=cut

sub addNamedPoint {
  my $self = shift;

  while (@_) {
    my $x = shift;
    my $y = shift;
    my $name = shift;

    push @$self, [ $x, $y, $name ];
  }

  return $self;
}

=head2 addHashPoints($xlabel, $ylabel, @points)

Add one or more data points to this piecewise linear estimator.

=over

=item $xlabel

The label for the x value of the data points.

=item $ylabel

The label for the y value of the data points.

=item @points

An array of hash references, each containing the x and y values for a data point.

=item Return Value

Returns the PiecewiseLinear estimator, so that method calls may be chained.

=cut

sub addHashPoints {
  my ($self, $xlabel, $ylabel, @points) = @_;
  
  my @new = ();

  foreach my $point (@points) {
    if (exists $point->{$xlabel} && exists $point->{$ylabel}) {
      push @new, $point->{$xlabel}, $point->{$ylabel};
    }
  }

  return $self->addPoint(@new);
}

=head2 addNamedHashPoints($xlabel, $ylabel, $namelabel, @points)

Add one or more data points to this piecewise linear estimator.

=cut

sub addNamedHashPoints {
  my ($self, $xlabel, $ylabel, $namelabel, @points) = @_;

  my @new = ();

  foreach my $point (@points) {
    if (exists $point->{$xlabel} && exists $point->{$ylabel} && exists $point->{$namelabel}) {
      push @new, $point->{$xlabel}, $point->{$ylabel}, $point->{$namelabel};
    }
  }

  return $self->addNamedPoint(@new);
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

    my $entry = [ $x, $y ];

    push @new, $entry;
  }

  @$self = sort { $a->[0] <=> $b->[0] } (@$self, @new);

  return $self;
}

=head2 getPoints

Return the points in the piecewise linear estimator.

=cut

sub getPoints {
  my ($self) = @_;

  return @$self;
}

=head2 estimate($x)

Return the interpolated/extrapolated Y value for the specified X value.

=over

=item $x

The X value for which a corresponding Y value is required.

=item Return Value

In a scalar context, returns the estimated Y value for the specified X value.
In a list context, returns an array of 1 or 2 elements. The first element is the estimated Y value. The second element is the name associated with that segment of the estimator, if one is available.

=back

=cut

sub estimate {
  my ($self, $x) = @_;

  # Handle empty estimator
  return if @$self == 0;

  # Handle single point
  if (@$self == 1) {
    if (wantarray) {
      if (defined $self->[0]->[2]) {
        return ($self->[0]->[1], $self->[0]->[2]);
      }
      return ($self->[0]->[1]);
    }
    return $self->[0]->[1];
  }

  # Handle extrapolation below range
  if ($x < $self->[0]->[0]) {
    return $self->_estimateFromPoints($x, $self->[0], $self->[1], $self->[0]);
  }

  # Handle extrapolation above range
  if ($x > $self->[-1]->[0]) {
    return $self->_estimateFromPoints($x, $self->[-2], $self->[-1], $self->[-1]);
  }

  # Handle exact matches
  for my $point (@$self) {
    if ($x == $point->[0]) {
      if (wantarray) {
        if (defined $point->[2]) {
          return ($point->[1], $point->[2]);
        }
        return ($point->[1]);
      }
      return $point->[1];
    }
  }

  # Find the segment for interpolation
  my $idx;
  for ($idx = 1; $idx < @$self; $idx++) {
    last if ($x < $self->[$idx]->[0]);
  }

  return $self->_estimateFromPoints($x, $self->[$idx-1], $self->[$idx], $self->[$idx-1]);
}

sub _estimateFromPoints {
  my ($self, $x, $lo, $hi, $name) = @_;

  my $y = ($lo->[1] * ($hi->[0] - $x) + $hi->[1] * ($x - $lo->[0])) / ($hi->[0] - $lo->[0]);

  if (wantarray) {
    if (defined $name->[2]) {
      return ($y, $name->[2]);
    }
    return ($y);
  }

  return $y;
}

=head2 length

Return the number of points in the piecewise linear estimator.

=cut

sub length {
  my ($self) = @_;

  return scalar(@$self);
}

=head2 start

The lowest X value represented by this estimator.

=cut

sub start {
  my ($self) = @_;

  return $self->[0]->[0];
}

=head2 end

The highest X value represented by this estimator.

=cut

sub end {
  my ($self) = @_;

  return $self->[-1]->[0];
}

1; 