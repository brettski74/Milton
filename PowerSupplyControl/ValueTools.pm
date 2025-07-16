package PowerSupplyControl::ValueTools;

use strict;
use warnings qw(all -uninitialized -digit);
use Carp qw(croak);
use base qw(Exporter);

our @EXPORT_OK = qw(boolify checkMinimum checkMaximum checkMinMax timestamp hexToNumber readCSVData);

=head1 NAME

PowerSupplyControl::ValueTools - A collection of functions for manipulating values.

=head1 SYNOPSIS

  use PowerSupplyControl::ValueTools qw(boolify checkMinimum checkMaximum checkMinMax timestamp);

  my $val = 5;
  checkMinimum($val, 10);
  print $val; # 10

  my $val = 15;
  checkMaximum($val, 10);
  print $val; # 10

  my $val = 20;
  checkMinMax($val, 5, 15);
  print $val; # 15

  my @vals = ( 0, 1, undef, 'false', 'False', 'true', 'FALSE');
  boolify(@vals);
  if ($val[0]) { print "true\n"; } # not true
  if ($val[1]) { print "true\n"; } # true
  if ($val[2]) { print "true\n"; } # not true
  if ($val[3]) { print "true\n"; } # not true
  if ($val[4]) { print "true\n"; } # not true
  if ($val[5]) { print "true\n"; } # true
  if ($val[6]) { print "true\n"; } # not true

=head1 DESCRIPTION

This module provides a collection of functions for manipulating values.

=head1 FUNCTIONS

=head2 boolify(@vals)

Convert a list of arbitrary values to booleans.

Mostly, this involves converting the string 'false' to zero, although it will also convert the string 'true' to one.

=cut

sub boolify {
  foreach my $val (@_) {
    if (lc($val) eq 'false') {
      $val = 0;
    } elsif (lc($val) eq 'true') {
      $val = 1;
    }
  }
}

=head2 checkMinimum($val, $min)

Check if the value is greater than the minimum. If it is not, set it to the minimum.

Returns true if the value was already greater than or equal to the minimum, otherwise returns false.

=cut

sub checkMinimum {
  my $rc = 1;

  while (@_ > 1) {
    if (!defined($_[0]) || $_[0] < $_[1]) {
      $_[0] = $_[1];
      $rc = undef;
    }

    shift;
    shift;
  }

  return 1 if $rc;
  return;
}

=head2 checkMaximum($val, $max)

Check if the value is less than the maximum. If it is not, set it to the maximum.

Returns true if the value was already less than or equal to the maximum, otherwise returns false.

=cut

sub checkMaximum {
  my $rc = 1;

  while (@_ > 1) {
    if (!defined($_[0]) || $_[0] > $_[1]) {
      $_[0] = $_[1];
      $rc = undef;
    }

    shift;
    shift;
  }

  return 1 if $rc;
  return;
}

=head2 checkMinMax($val, $min, $max)

Check if the value is within the specified range. If it is not, set it to the nearest boundary.

Returns true if the value was already within the range, otherwise returns false.

=cut

sub checkMinMax {
  croak "checkMinMax: Maximum value $_[2] is less than minimum value $_[1]" if $_[2] < $_[1];

  if ($_[0] < $_[1]) {
    $_[0] = $_[1];
    return;
  }

  if ($_[0] > $_[2]) {
    $_[0] = $_[2];
    return;
  }

  return 1;
}

=head2 timestamp([$when])

Return a timestamp in the format YYYYMMDD-HHMMSS.

=over

=item $when

The time specified as the number of seconds since epoch. If not specified, the current time is used.

=back

=cut

sub timestamp {
  my $when = shift // time;

  my ($sec, $min, $hour, $day, $month, $year) = localtime($when);
  return sprintf("%04d%02d%02d-%02d%02d%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);
}

=head2 hexToNumber(@hexData)

Convert a list of hexadecimal strings to numbers.

=cut

sub hexToNumber {
  for (my $i=0; $i<@_; $i++) {
    $_[$i] = hex($_[$i]);
  }
}

=head2 readCSVData($filename)

Read a CSV file and return an array of hashes.

=over

=item $filename

The name of the CSV file to read. The first line of the file must be a header line defining the
key names associated with each column.

=item Return Value

An array of hashes, one for each line in the CSV file.

=cut

sub readCSVData {
  my ($filename) = @_;
  my $fh = IO::File->new($filename, 'r') || croak "Failed to open $filename: $!";
  my $header = $fh->getline;
  chomp $header;
  my @columns = split /,/, $header;

  my $data = [];
  while (my $line = $fh->getline) {
    chomp $line;
    my @values = split /,/, $line;
    my $record = {};
    for (my $i = 0; $i < @values; $i++) {
      $record->{$columns[$i]} = $values[$i];
    }
    push @$data, $record;
  }
  $fh->close;
  return $data;
}

=head1 AUTHOR

Brett Gersekowski

=head1 LICENSE

This perl module is distribute under an MIT license. See the LICENSE file for details.

=cut

1;