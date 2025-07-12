package PowerSupplyControl::Math::SimpleLinearRegression;

use strict;
use warnings qw(all -uninitialized);

use Carp qw(croak);

=head1 NAME

PowerSupplyControl::Math::SimpleLinearRegression - Simple linear regression

=head1 SYNOPSIS

=head1 DESCRIPTION

Perform simple linear regression on a set of data points.

Given a set of data point (x, y), calculate the parameters of a line

  y = gradient * x + intercept

such that it minimizes the sum of the squares of the vertical distances from the line to each data point.

=head1 CONSTRUCTOR

=head2 new($x, $y, {$x, $y, ...})

Create a new SimpleLinearRegression Object.

=over

=item $x

The x value of a data point.

=item $y

The y value of a data point.

=back

=cut

sub new {
  my ($class, @data) = @_;

  my $self = { xsum => 0
             , ysum => 0
             , x2sum => 0
             , xysum => 0
             , n => 0
             };

  bless $self, $class;

  $self->addData(@data);

  return bless $self, $class;
}

=head1 METHODS

=head2 addData($x, $y, {$x, $y, ...})

Add one or more data points to the regression.

=over

=item @data

The x value of a data point.

=item $y

The y value of a data point.

=back

=cut

sub addData {
  my ($self, @data) = @_;
  my $xsum = $self->{xsum};
  my $ysum = $self->{ysum};
  my $x2sum = $self->{x2sum};
  my $xysum = $self->{xysum};
  my $n = $self->{n};

  while (@data) {
    my $x = shift @data;
    my $y = shift @data;

    if (!defined $x || !defined $y) {
      croak 'Invalid data point ($x, $y)';
    }

    $xsum += $x;
    $ysum += $y;
    $x2sum += $x * $x;
    $xysum += $x * $y;
    $n++;
  }

  if ($n > 1) {
    my $gradient = ($n * $xysum - $xsum * $ysum) / ($n * $x2sum - $xsum * $xsum);
    $self->{intercept} = ($ysum - $gradient * $xsum) / $n;

    $self->{gradient} = $gradient;
  }

  $self->{xsum} = $xsum;
  $self->{ysum} = $ysum;
  $self->{x2sum} = $x2sum;
  $self->{xysum} = $xysum;
  $self->{n} = $n;

  return $self;
}

=head addHashData($xkey, $ykey, @data)

Add one or more data points to the regression from data encapsulated in hashes.

=over

=item $xkey

The key of the x value in the data points.


=item $ykey

The key of the y value in the data points.

=item @data

A list of one or more hash references containing the data points.

=back

=cut

sub addHashData {
  my ($self, $xkey, $ykey, @data) = @_;

  my @points = ();

  foreach my $point (@data) {
    if (defined $point->{$xkey} && defined $point->{$ykey}) {
      push @points, $point->{$xkey}, $point->{$ykey};
    }
  }

  return $self->addData(@points);
}

=head2 gradient()

Return the gradient of the regression line.

=cut

sub gradient {
  my $self = shift;

  return $self->{gradient};
}

=head2 intercept()

Return the intercept of the regression line.

=cut

sub intercept {
  my $self = shift;

  return $self->{intercept};
}

=head2 xsum()

Return the sum of the x values of the data points.

=cut

sub xsum {
  my $self = shift;

  return $self->{xsum};
}

=head2 ysum()

Return the sum of the y values of the data points.

=cut

sub ysum {
  my $self = shift;

  return $self->{ysum};
}

=head2 x2sum()

Return the sum of the squares of the x values of the data points.

=cut

sub x2sum {
  my $self = shift;

  return $self->{x2sum};
}

=head2 xysum()

Return the sum of the products of the x and y values of the data points.

=cut

sub xysum {
  my $self = shift;

  return $self->{xysum};
}

=head2 n()

Return the number of data points used in the regression.

=cut

sub n {
  my $self = shift;

  return $self->{n};
}

1;