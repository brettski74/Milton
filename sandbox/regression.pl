use List::Util qw(sum);

# Inputs: arrays of P_in, temperatures, ambient
my (@P_in, @T, $T_ambient, $dt) = ...;

# Build sums
my ($S_PP, $S_PT, $S_TT, $S_TP, $N) = (0, 0, 0, 0, scalar @P_in - 1);

for my $i (0 .. $N-1) {
    my $dT      = $T[$i + 1] - $T[$i];
    my $power   = $P_in[$i];
    my $temp_diff = $T[$i] - $T_ambient;

    $S_PP += $power * $power;
    $S_PT += $power * $dT;
    $S_TT += $temp_diff * $temp_diff;
    $S_TP += $temp_diff * $dT;
}

# Solve the linear system:
# ΔT = a·P_in - b·(T-T_ambient)

# Normal equations:
# [ ΣP_in^2       -ΣP_in·(T_diff) ] [a] = [ ΣP_in·ΔT ]
# [ -ΣP_in·(T_diff)   Σ(T_diff)^2 ] [b] = [-Σ(T_diff)·ΔT]

# Invert the 2x2
my $den = $S_PP * $S_TT - $S_TP**2;

my $a = ($S_TT * $S_PT - $S_TP * $S_TP) / $den;
my $b = ($S_PP * (-$S_TP) - $S_TP * $S_PT) / $den;

# Final Parameters:
my $C      = $dt / $a;
my $R_theta = $a / $b;

print "C = $C J/K\nR_θ = $R_theta K/W\n";

