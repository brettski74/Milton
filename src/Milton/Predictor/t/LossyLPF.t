#1/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib qw(.);

use Test2::V0;

use Milton::Predictor::LossyLPF;

my $EPS = 1e-6;

subtest 'defaults' => sub {
  my $p = Milton::Predictor::LossyLPF->new;

  my $sts = sub {
    return { ambient => 25.3, period => 1.5, temperature => shift };
  };

  my @temps = ( [ 25.3, 25.3 ]
              , [ 25.6, 25.3146052631579 ]
              , [ 28, 25.445283933518 ]
              , [ 35, 25.9098742528065 ]
              , [ 45, 26.8368545552904 ]
              , [ 58, 28.3479411576435 ]
              );

  foreach my $test (@temps) {
    my $status = $sts->($test->[0]);
    is($p->predictTemperature($status), float($test->[1], tolerance => $EPS), "predictTemperature($test->[0])");
    is($status->{'predict-temperature'}, float($test->[1], tolerance => $EPS), "status($test->[0])");
  }
};

done_testing;
