package Milton::Math::PiecewiseLinear;

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
  my @points = ();

  while (@_) {
    my $x = shift;
    my $y = shift;
    my $name = shift;

    push @points, { x => $x, y => $y, name => $name };
  }

  return $self->addHashPoints('x', 'y', @points);
}

=head2 setNamedPoint($x, $y, $name)

Set the value for a named point.

=over

=item $name

The name of the point to set.

=item $x

The x value of the point to set.

=item $y

The y value of the point to set.

=item Return Value

Returns the PiecewiseLinear estimator, so that method calls may be chained.

=cut

sub setNamedPoint {
  my ($self, $x, $y, $name) = @_;

  my $point;

  for (my $i=0; $i < @$self; $i++) {
    my $attributes = $self->[$i]->[2];

    if ($attributes && $attributes->{name} eq $name) {
      ($point) = splice @$self, $i, 1;
      last;
    }
  }

  return $self->addNamedPoint($x, $y, $name);
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
      my $done = 0;
      my $x = $point->{$xlabel};
      my $y = $point->{$ylabel};

      for (my $i = 0; $i < @$self; $i++) {
        if ($self->[$i]->[0] > $x) {
          splice @$self, $i, 0, [ $x, $y, $point ];
          $done = 1;
          last;
        } elsif ($self->[$i]->[0] == $x) {
          $self->[$i] = [ $x, $y, $point ];
          $done = 1;
          last;
        }
      }

      if (!$done) {
        push @$self, [ $x, $y, $point ];
      }
    }
  }

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

    push @new, { x => $x, y => $y };
  }

  return $self->addHashPoints('x', 'y', @new);
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
In a list context, returns an array of 1 or 2 elements. The first element is the estimated Y value.
The second element is the hash of attributes associated with that segment of the estimator.

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

  return $self->_estimateFromPoints($x, $self->[$idx-1], $self->[$idx], $self->[$idx]);
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
