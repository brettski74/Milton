use strict;
use warnings;
use List::Util qw(sum);

# Dummy data arrays
my @time = (0, 10, 20, 30, 40, 50);     # example times
my @temp = (25, 50, 70, 85, 95, 100);   # example measured temps

my $T_ambient = 25;
my $T_final   = $temp[-1]; # use last measured temp as estimate of final temp

# Build log-transformed y values
my @log_y;
for my $i (0 .. $#time) {
    my $diff = $T_final - $temp[$i];
    next if $diff <= 0; # avoid log of non-positive
    push @log_y, log($diff);
}

# Fit log_y = log(ΔT) - t/τ as a straight line: y = a + b*t
# using least-squares to get slope b and intercept a
my $n = @log_y;
my $sum_t  = sum @time[0 .. $n-1];
my $sum_y  = sum @log_y;
my $sum_tt = sum(map { $_ * $_ } @time[0 .. $n-1]);
my $sum_ty = sum(map { $time[$_] * $log_y[$_] } 0 .. $n-1);

my $slope = ($n * $sum_ty - $sum_t * $sum_y) / ($n * $sum_tt - $sum_t**2);
my $intercept = ($sum_y - $slope * $sum_t) / $n;

my $tau = -1 / $slope;

print "Estimated time constant τ = $tau seconds\n";

