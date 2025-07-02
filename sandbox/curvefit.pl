use Math::CurveFit;

my $cf = Math::CurveFit->new(
    function => sub {
        my ($t, $T_ambient, $Delta_T, $tau) = @_;
        return $T_ambient + $Delta_T * (1 - exp(-$t/$tau));
    },
    params => [$T_ambient, $T_final-$T_ambient, 100], # guesses
);

my @data = map { [$time[$_], $temp[$_]] } 0 .. $#time;
my ($params, $chisq) = $cf->fit(\@data);
my ($T_amb_fitted, $Delta_T, $tau_fitted) = @$params;

