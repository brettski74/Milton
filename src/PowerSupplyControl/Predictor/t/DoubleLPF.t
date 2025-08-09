#1/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib qw(.);

use Test2::V0;

use PowerSupplyControl::Predictor::DoubleLPF;

my $EPS = 1e-6;

subtest 'defaults' => sub {
  my $p = PowerSupplyControl::Predictor::DoubleLPF->new;

  my $sts = sub {
    return { ambient => 25.3, period => 1.5, temperature => shift };
  };

  my @temps = ( [ 25.3, 25.3 ]
              , [ 25.6, 25.3157109190888 ]
              , [ 28, 25.4562082505157 ]
              , [ 35, 25.9552368949612 ]
              , [ 45, 26.9493461172716 ]
              , [ 58, 28.5672547845451 ]
              , [ 70, 30.7208214779687 ]
              , [ 80, 33.274589505286 ]
              , [ 94, 36.4150883003481 ]
              , [ 106, 40.0039324119543 ]
              );

  foreach my $test (@temps) {
    my $status = $sts->($test->[0]);
    is($p->predictTemperature($status), float($test->[1], tolerance => $EPS), "predictTemperature($test->[0])");
    is($status->{'predict-temperature'}, float($test->[1], tolerance => $EPS), "status($test->[0])");
  }
};

done_testing;
