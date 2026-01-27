package Milton::Math::Util;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use Scalar::Util qw(reftype);
use Exporter 'import';
use Time::HiRes qw(time);
use IO::Pipe;
use Storable qw(store_fd fd_retrieve);
use POSIX qw(ceil);

our @EXPORT_OK = qw(
  maximum
  mean
  meanSquaredError
  minimum
  minimumSearch
  setDebug
  setDebugWriter
  sgn
);

my $DEBUG = 0;
my $DEBUG_WRITER = undef;

=head1 NAME

Milton::Math::Util - Mathematical utility functions for the HP Controller

=head1 SYNOPSIS

    use Milton::Math::Util qw(meanSquaredError);
    
    # Calculate MSE between a function and sample data
    my $mse = meanSquaredError($function, @samples);

=head1 DESCRIPTION

This module provides mathematical utility functions used throughout the HP Controller
system for data analysis and signal processing.

=head1 FUNCTIONS

=head2 meanSquaredError($fn, @samples)

    my $mse = meanSquaredError($function, @samples);

Calculates the Mean Squared Error (MSE) between a function and a set of sample data points.

The MSE is a measure of the average squared difference between predicted values
(from the function) and actual values (from the samples). It's commonly used in
statistics and machine learning to assess the quality of a model or function fit.

=head3 Theory

The Mean Squared Error is calculated as:

    MSE = (1/n) * Σ(y_predicted - y_actual)²

Where:
- n is the number of samples
- y_predicted is the value returned by the function for each input
- y_actual is the actual output value from the sample

=head3 Parameters

=over 4

=item $function

A code reference (subroutine reference) representing the expected function relating inputs
to outputs. The function should take each sample array and return a predicted result value.
The sample array will not be altered and so will include the sampled result. It is up to the
caller to make sure the provided subroutine ignores the sampled result value. The subroutine
must not alter the provided sample array.

=item @samples

A list of sample data points. Each sample should be a reference to an array with two elements.
The first element is the input value and the second element is the sampled result for that input.
The input value is what will be passed to your expected function. The result value is what will
be compared to the output of your expected function.

=back

=head3 Returns

Returns a scalar value representing the mean squared error. The result is always
non-negative, with lower values indicating better agreement between the function
and the sample data.

=head3 Examples

=head4 Basic Usage

    use Milton::Math::Util qw(meanSquaredError);
    
    # Define a simple linear function: f(x) = 2x + 1
    my $linear_fn = sub { my $x = shift; return 2 * $x + 1; };
    
    # Sample data: [input, expected_output]
    my @samples = ([1, 3], [2, 5], [3, 7], [4, 9], [5, 11]);
    
    # Calculate MSE
    my $mse = meanSquaredError($linear_fn, @samples);
    # For perfect fit, MSE would be 0
    # For this example, MSE = (1/5) * Σ((2x+1 - sampled)²)

=head4 Function Approximation

    # Test how well a constant function approximates data
    my $constant_fn = sub { return 3.5; } # Always returns 3.5
    my @data = ([1, 3.1], [2, 3.4], [3, 3.8], [4, 3.2], [5, 3.9]);
    
    my $mse = meanSquaredError($constant_fn, @data);
    # This will give the MSE of using 3.5 as a constant approximation

=head4 Model Validation

    # Validate a temperature conversion function
    my $temp_convert = sub { 
        my $celsius = shift; 
        return $celsius * 9/5 + 32;  # Celsius to Fahrenheit
    };
    
    # Sample data: [celsius_input, expected_fahrenheit_output]
    my @samples = ([0, 32], [10, 50], [20, 68], [30, 86], [40, 104]);
    
    my $mse = meanSquaredError($temp_convert, @samples);
    # Perfect conversion should give MSE = 0

=head4 Multi-parameter Function

    # Function with multiple inputs: f(x, y) = x + 2*y
    my $multi_param_fn = sub {
        my @sample = @_;
        my $x = $sample[0];  # First input
        my $y = $sample[1];  # Second input
        return $x + 2 * $y;  # Predicted output
    };
    
    # Sample data: [x, y, expected_output]
    my @samples = ([1, 2, 5], [3, 1, 5], [0, 3, 6], [2, 2, 6]);
    
    my $mse = meanSquaredError($multi_param_fn, @samples);
    # Tests how well the function predicts the expected outputs

=cut

sub meanSquaredError {
  my ($fn, @samples) = @_;

  croak 'No samples provided.' unless @samples;
  croak 'Expected function is not a code reference.' unless reftype($fn) eq 'CODE';

  my $sum = 0;
  for (my $idx = 0; $idx < @samples; $idx++) {
    my $sample = $samples[$idx];
    croak "Sample $idx is not an array reference." unless reftype($sample) eq 'ARRAY';
    croak "Sample $idx has less than 2 elements." unless @$sample >= 2;

    my $error = $fn->(@{$samples[$idx]}) - $samples[$idx]->[-1];
    $sum += $error * $error;
  }

  return $sum / scalar(@samples);
}

=head2 sgn($x)

Return a value indicating the sign of the specified number.

=over

=item $x

The number for which the sign is to be determined.

=item Return Value

Returns 1 if $x is greater than 0, -1 if $x is less than 0, 0 if $x is 0 or undef otherwise.

=back

=cut

sub sgn {
  my $x = shift;

  if ($x > 0) {
    return 1;
  }
  if ($x < 0) {
    return -1;
  }
  if (defined $x) {
    return 0;
  }

  return;
}

=head2 mean($values, $key1, $val1{, $key2, $val2, ...})

Calculate mean values from a list of hashes.

=over

=item $values

A reference to a list of hash references.

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be averaged will be taken.

=item $val1, $val2, ..., $valN

The set of variables to which the mean values will be assigned.

=cut

sub mean {
  my $values = shift;
  my @count = ();

  for (my $idx = 1; $idx < @_; $idx += 2) {
    $_[$idx] = undef;
    $count[$idx] = 0;
  }

  foreach my $row (@$values) {
    for (my $idx = 1; $idx < @_; $idx += 2) {
      my $key = $_[$idx-1];
      
      if (defined $row->{$key}) {
        $_[$idx] += $row->{$key};
        $count[$idx]++;
      }
    }
  }

  for (my $idx = 1; $idx < @_; $idx += 2) {
    $_[$idx] /= $count[$idx] if defined($_[$idx]) && $count[$idx] > 0;
  }

  return;
}

=head2 minimum($values, $key1, $val1{, $key2, $val2, ...})

Calculate the minimum value from a list of hashes.

=over

=item $values

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be reviewed.

=item $val1, $val2, ..., $valN

The set of variables to which the minimum values will be assigned.

=cut

sub minimum {
  my $values = shift;

  for (my $i=1; $i < @_; $i += 2) {
    $_[$i] = undef;
  }

  foreach my $row (@$values) {
    for (my $i = 1; $i < @_; $i += 2) {
      my $key = $_[$i-1];
      if (defined $row->{$key}) {
        if (!defined($_[$i]) || $_[$i] > $row->{$key}) {
          $_[$i] = $row->{$key};
        }
      }
    }
  }

  return;
}

=head2 maximum($values, $key1, $val1{, $key2, $val2, ...})

Calculate the maximum value from a list of hashes.

=over

=item $values

=item $key1, $key2, ..., $keyN

The hash keys corresponding to each variable from which the sample data to be reviewed.

=item $val1, $val2, ..., $valN

The set of variables to which the maximum values will be assigned.

=cut

sub maximum {
  my $values = shift;

  for (my $i=1; $i < @_; $i += 2) {
    $_[$i] = undef;
  }

  foreach my $row (@$values) {
    for (my $i = 1; $i < @_; $i += 2) {
      my $key = $_[$i-1];
      if (defined $row->{$key}) {
        if (!defined($_[$i]) || $_[$i] < $row->{$key}) {
          $_[$i] = $row->{$key};
        }
      }
    }
  }

  return;
}

=head2 minimumSearch($fn, $lo, $hi, $steps, $threshold, %options)

Search for the minimum value of a univariate function. The search will continue
recursively on smaller and smaller sub-ranges until the difference between $lo
and $hi is less than or equal to a $threshold.

=over

=item $fn

A code reference representing the function to be searched. The function must take a
single scalar argument and return a scalar value.

=item $lo

The minimum value of the search space.

=item $hi

The maximum value of the search space.

=item %options

Additional optional named parameters that may be supplied.

=over

=item steps

the number of steps into which the search space will be divided. If not specified, defaults to 100.

=item $threshold

The maximum value allowed between $lo and $hi. If the difference between $lo and $hi is less than this value,
the search will stop and return the average of $lo and $hi. If not specified, defaults to 0.01.

=item $lower_constrained

If true, the search will never search below $lo. Defaults to false.

=item $upper_constrained

If true, the search will never search above $hi. Defaults to false.

=back

=item Return Value

Returns the value of the independent variable that produces the minimum value of the
provided function.

=back

=cut

sub _new_bounds {
  my ($best, $lo, $hi, $step, $steps, $lo_constraint, $hi_constraint, $re_flag) = @_;
  my $bottom = $best - $step;
  my $top = $best + $step;
  
  if ($bottom < $lo) {
    if ($re_flag < 0) {
      # Range extended on the bottom twice in a row, so accelerate range extension
      $step = $step * 5;
    }
    $bottom -= ($step * ($steps - 2));
    
    # Add a little something onto the top as well to help ensure we land somewhere in the middle next pass
    $top += $step;

    $re_flag = -1;
  } elsif ($top > $hi) {
    if ($re_flag > 0) {
      # Range extended on the top twice in a row, so accelerate range extension
      $step = $step * 5;
    }
    $top += ($step * ($steps - 2));

    # Add a little something onto the bottom as well to help ensure we land somewhere in the middle next pass
    $bottom -= $step;

    $re_flag = 1;
  }

  if (defined($lo_constraint) && $bottom < $lo_constraint) {
    $bottom = $lo_constraint;
    $re_flag = 0;
  }

  if (defined($hi_constraint) && $top > $hi_constraint) {
    $top = $hi_constraint;
    $re_flag = 0;
  }

  return ( $bottom, $top, $re_flag );
}

sub setDebug {
  $DEBUG = shift;
  return $DEBUG;
}

sub writeDebug {
  my ($message) = @_;
  if ($DEBUG) {
    if ($DEBUG_WRITER) {
      $DEBUG_WRITER->($message);
    } else {
      print "$message\n";
    }
  }
}

sub setDebugWriter {
  $DEBUG_WRITER = shift;
}
sub _spawnChildren {
  my ($search, $fn, $count) = @_;
  my @children;

  writeDebug("Spawning $count children");

  while (@children < $count) {
    my $send = IO::Pipe->new;
    my $recv = IO::Pipe->new;
    if (my $pid = fork) {
      # Parent
      $send->writer;
      $recv->reader;
      $send->autoflush(1);
      push @children, { send => $send, recv => $recv, pid => $pid };
    } elsif (defined $pid) {
      # Child
      $send->reader;
      $recv->writer;
      $recv->autoflush(1);
      while (my $args = fd_retrieve($send)) {
        last if !@$args;
        my @best = $search->($fn, @$args);
        store_fd(\@best, $recv);
      }
      exit 0;
    } else {
      croak "Unable to fork: $!";
    }
  }

  return @children;
}

sub _splitBounds {
  my ($bounds, $steps, $count) = @_;

  # Find the bound with the largest range
  my $max_range = 0;
  my $max_range_idx = 0;
  for(my $i=0; $i < @$bounds; $i++) {
    my $range = $bounds->[$i]->[1] - $bounds->[$i]->[0];
    if ($range > $max_range) {
      $max_range = $range;
      $max_range_idx = $i;
    }
  }

  my $small_steps = ceil($steps->[$max_range_idx] / $count);
  my $small_range = $max_range / $count;
  my $last_step = 1 - 1/$small_steps;
  my @rc;

  for(my $i=0; $i < $count; $i++) {
    my $b = [ map { [ @$_ ] } @$bounds ];
    my $s = [ @$steps ];

    $s->[$max_range_idx] = $small_steps;
    $b->[$max_range_idx]->[0] = $bounds->[$max_range_idx]->[0] + $i * $small_range;
    $b->[$max_range_idx]->[1] = $b->[$max_range_idx]->[0] + $last_step * $small_range;

    $rc[$i] = { bounds => $b, steps => $s };
  }

  return @rc;
}

sub _taskChildren {
  my ($children, $bounds, $steps) = @_;

  my @b = _splitBounds($bounds, $steps, scalar(@$children));

  foreach my $child (@$children) {
    my $b = pop @b;

    store_fd([ $b->{bounds}, $b->{steps} ], $child->{send});
  }

  my @best;
  my $best_y;
  my $worst_y;
  foreach my $child (@$children) {
    my $rc = fd_retrieve($child->{recv});
    my $wy = pop @$rc;
    my $by = pop @$rc;
    if (!defined($best_y) || $by < $best_y) {
      $best_y = $by;
      @best = @$rc;
    }
    if (!defined($worst_y) || $wy > $worst_y) {
      $worst_y = $wy;
    }
  }

  return ( @best, $best_y, $worst_y );
}

sub _shutdownChildren {
  my ($children) = @_;
  my $killswitch = [];
  foreach my $child (@$children) {
    store_fd($killswitch, $child->{send});
    waitpid($child->{pid}, 0);
    $child->{send}->close;
    $child->{recv}->close;
  }
  return;
}

sub countCores {
  my $fh = IO::File->new('/proc/cpuinfo');
  return 1 if !$fh;

  my $cores = 0;
  while (my $line = $fh->getline) {
    chomp $line;

    # Only count cores that have a floating point unit
    if ($line =~ /^fpu\s*: yes/) {
      $cores++;
    }
  }

  return $cores || 1;
}

sub minimumSearch {
  my ($fn, $bounds, %options) = @_;

  my $start = time;
  my $elapsed = $start;

  die 'bounds is not an array reference.' unless reftype($bounds) eq 'ARRAY';

  my $threshold = $options{threshold} // 0.001;
  if (!ref($threshold)) {
    $threshold = [ map $threshold, @$bounds ];
  }

  my $y_threshold = $options{'y-threshold'};

  my $steps = $options{steps} // 30;
  if (!ref($steps)) {
    $steps = [ map $steps, @$bounds ];
  }

  for(my $i=0; $i < @$bounds; $i++) {
    croak "bounds[$i] is not an array reference." if reftype($bounds->[$i]) ne 'ARRAY';
    croak "bounds[$i] is out of order: [ $bounds->[$i]->[0], $bounds->[$i]->[1] ]" if $bounds->[$i]->[0] > $bounds->[$i]->[1];

    # Make sure we have a valid threshold for each dimension
    $threshold->[$i] //= 0.001;
    croak "Invalid threshold for dimension $i: $threshold->[$i]. Must be positive." if $threshold->[$i] <= 0;

    # Make sure we have a valid steps for each dimension
    $steps->[$i] //= 24;
    croak "Invalid steps for dimension $i: $steps->[$i]. Must be at least 4." if $steps->[$i] < 4;
  }

  # Check search depth limit for sanity
  my $depth = $options{depth} // 100;
  croak "Invalid depth: $depth. Must be positive." if $depth <= 0;

  my $search = _searchFunction(scalar(@$bounds));
  my $best_y;
  my $worst_y;
  my @children;

  my $parallel = $options{parallel} // countCores();

  if ($parallel > 1) {
    @children = _spawnChildren($search, $fn, $parallel);
  }

  while ($depth > 0) {
    if ($DEBUG) {
      my $sep = 'limits: ';
      my $msg = '';
      foreach my $bound (@$bounds) {
        $msg .= sprintf("${sep}[ %.6f, %.6f ]", $bound->[0], $bound->[1]);
        $sep = ', ';
      }
      writeDebug($msg);
    }

    $depth--;

    my @best;
    if (@children) {
      @best = _taskChildren(\@children, $bounds, $steps);
    } else {
      @best = $search->($fn, $bounds, $steps);
    }

    $worst_y = pop @best;
    $best_y = pop @best;

    # Determine if we've met our end conditions
    my $done = 1;
    my @range;
    for(my $i=0; $i < @$bounds; $i++) {
      $range[$i] = $bounds->[$i]->[1] - $bounds->[$i]->[0];
      if ($range[$i] > $threshold->[$i]) {
        $done = 0;
      }
    }

    if ($done || (defined($y_threshold) && $best_y <= $y_threshold)) {
      _shutdownChildren(\@children) if @children;

      if ($DEBUG) {
        my $end = time;
        my $msg = sprintf('best: [ '
                        . join(', ', map '%.6f', @best)
                        . ' ], best-y: %.6f, elapsed: %.3f seconds'
                        , @best
                        , $best_y
                        , $end - $start
                        );
        writeDebug($msg);
      }

      if (wantarray || @best > 1) {
        return @best;
      }
      return $best[0];
    }

    # Update the limits for the next iteration
    my $msg;
    my @params;
    if ($DEBUG) {
      $msg = 'elapsed: %.3f seconds';
      @params = ( $elapsed );
    }

    for (my $i=0; $i < @$bounds; $i++) {
      my $bound = $bounds->[$i];
      my $step = $range[$i] / $steps->[$i];
      @$bound = _new_bounds($best[$i], $bound->[0], $bound->[1], $step, $steps->[$i], $options{'lower-constraint'}->[$i], $options{'upper-constraint'}->[$i], $bound->[2]);
      if ($DEBUG) {
        if ($range[$i] > $threshold->[$i]) {
          $msg .= ", range%d: %.6f > $threshold->[$i] (%.6f)";
          push @params, $i, $range[$i], $best[$i];
        }
      }
    }

    if ($DEBUG) {
      my $end = time;
      $params[0] = $end - $elapsed;
      $elapsed = $end;

      $msg .= ', best-y: %.6f, worst-y: %.6f, depth: %d';
      push @params, $best_y, $worst_y, $depth;
      writeDebug(sprintf($msg, @params));
    }
  }

  croak 'Search depth exceeded.';
  return;
}

sub _generatePreciseSteps {
  my ($lower, $upper, $steps) = @_;

  my $rc = [ $lower ];
  $rc->[$steps] = $upper;

  # Count in from each end, stopping in the middle
  for(my $i=$steps>>1; $i > 0; $i--) {
    my $offset = $i * ($upper - $lower) / $steps;
    $rc->[$i] = $lower + $offset;
    $rc->[$steps-$i] = $upper - $offset;
  }

  return $rc;
}

  
my @SEARCH_FUNCTIONS = ();

# A bit of a hack, but I can't think of a better way to generalize an aribtrary depth nesting of loops
# Without doing code generation.
sub _searchFunction {
  my ($dimensions) = @_;

  if (!defined $SEARCH_FUNCTIONS[$dimensions-1]) {
    my $code = <<'EOS';
sub {
  my ($fn, $bounds, $steps) = @_;

  my @range;
  my @step;
  my @args;

  for(my $i=0; $i<@$bounds; $i++) {
    $range[$i] = $bounds->[$i]->[1] - $bounds->[$i]->[0];
    $step[$i] = $range[$i] / $steps->[$i];
    $args[$i] = $bounds->[$i]->[0];
  }

  my @best = @args;
  my $best_y = $fn->(@args);
  my @worst = @args;
  my $worst_y = $best_y;

EOS

  for (my $i=0; $i<$dimensions; $i++) {
    $code .= <<"EOS";
  my \$vals$i = _generatePreciseSteps(\$bounds->[$i]->[0], \$bounds->[$i]->[1], \$steps->[$i]);
EOS
  }

  my $indent;
  # Add in the loop statements for each dimension
  for(my $i=0; $i<$dimensions; $i++) {
    $indent = ' ' x (2 * ($i+1));

    $code .= <<"EOS";

${indent}foreach my \$val$i (\@\$vals$i) {
${indent}  \$args[$i] = \$val$i;
EOS
  }
  
  $code .= <<"EOS";
$indent  my \$y = \$fn->(\@args);

$indent  if (\$y < \$best_y) {
$indent    \$best_y = \$y;
$indent    \@best = \@args;
$indent  }

$indent  if (\$y > \$worst_y) {
$indent    \$worst_y = \$y;
$indent    \@worst = \@args;
$indent  }
EOS

  for(my $i=$dimensions-1; $i >= 0; $i--) {
    $indent = ' ' x (2 * ($i+1));
    $code .= "$indent}\n";
  }

  $code .= <<'EOS';
  return (@best, $best_y, $worst_y);
}
EOS

    $SEARCH_FUNCTIONS[$dimensions-1] = eval $code;
    die "Error in search function: $@" if $@;
  }

  die "Search function for $dimensions dimensions not found." unless defined $SEARCH_FUNCTIONS[$dimensions-1];

  return $SEARCH_FUNCTIONS[$dimensions-1];
}

1;