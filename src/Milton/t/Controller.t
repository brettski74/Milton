#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib qw(.);

use Test2::V0;

use Milton::Controller;

subtest getAmbient => sub {
  my $status = {};
  my $c = Milton::Controller->new();

  is($c->getAmbient($status), 25, 'Nothing available except default default');
  is($status->{ambient}, 25);

  $status = { temperature => 26 };
  is($c->getAmbient($status), 26, 'Valid temperature (26) available');
  is($status->{ambient}, 26);

  $status = { temperature => 24 };
  is($c->getAmbient($status), 24, 'Valid temperature (24) available');
  is($status->{ambient}, 24);

  $status = { temperature => 19 };
  is($c->getAmbient($status), 19, 'Low temperature (19) available');
  is($status->{ambient}, 19);

  $status = { temperature => 24, 'device-temperature' => 25, 'device-ambient' => 24.1 };
  is($c->getAmbient($status), 24.1, 'Device-ambient lower than device-temperature');
  is($status->{ambient}, 24.1);

  $status = { temperature => 24.4, 'device-temperature' => 25, 'device-ambient' => 24.1 };
  is($c->getAmbient($status), 24.1, 'Device-ambient lower than device-tempature');
  is($status->{ambient}, 24.1);

  $status = { temperature => 29.6, 'device-temperature' => 26.1, 'device-ambient' => 26.7 };
  is($c->getAmbient($status), 26.1, 'Device-temperature lower than device-temperature');
  is($status->{ambient}, 26.1);

  $status = { temperature => 24.4, 'device-temperature' => 25, 'device-ambient' => 19.6 };
  is($c->getAmbient($status), 19.6, 'Device-ambient much lower');
  is($status->{ambient}, 19.6);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, 'device-ambient' => 27.1 };
  is($c->getAmbient($status), 27.1);
  is($status->{ambient}, 27.1);

  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 25, 'Temperature and device-temperature too high');
  is($status->{ambient}, 25);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, ambient => 27.1 };
  is($c->getAmbient($status), 27.1, 'Temperature and device-temperature too high, with device-ambient');
  is($status->{ambient}, 27.1);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, ambient => 31 };
  is($c->getAmbient($status), 31, 'Temperature and device-temperature too high, with ambient');
  is($status->{ambient}, 31);

  $c->{limits}->{ambient} = 27.3;
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 27.3, 'User default with temperature and device-temperature too high');
  is($status->{ambient}, 27.3);

  $c = Milton::Controller->new({limits => {ambient => 27.6}});
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 27.6, 'User default with device temperature within limits');
  is($status->{ambient}, 27.6);

  $c = Milton::Controller->new({limits => {ambient => 27.6}});
  $status = { temperature => 37.5, 'device-temperature' => 33.7 };
  is($c->getAmbient($status), 27.6, 'User default with temperature and device temperature too high');
  is($status->{ambient}, 27.6);

  $c->{limits}->{ambient} = 28.2;
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 28.2);
  is($status->{ambient}, 28.2);

};

subtest getPowerLimited => sub {
  my $status = {};
  my $c = Milton::Controller->new({ limits => { 'power-limits' => [ { temperature => 20, power => 120 }
                                                                              , { temperature => 220, power => 120 }
                                                                              , { temperature => 230, power => 50 }
                                                                              ]
                                                          , 'cut-off-temperature' => 227
                                                          }
                                              });

  is($c->getPowerLimited({ power => 60 }), 60, 'No temperature available - pass-thru');
  is($c->getPowerLimited({ power => 160 }), 160, 'No temperature available - pass-thru');

  my @testdata = ( [ 55, 10, 55 ]
                 , [ 155, 10, 120, 155 ]
                 , [ 56, 20, 56 ]
                 , [ 156, 20, 120, 156 ]
                 , [ 75, 100, 75 ]
                 , [ 175, 100, 120, 175 ]
                 , [ 90, 220, 90 ]
                 , [ 120, 220, 120 ]
                 , [ 121, 220, 120, 121 ]
                 , [ 120, 225, 85, 120 ]
                 , [ 84, 225, 84 ]
                 , [ 50, 227, 0, 50 ]
                 , [ 90, 227, 0, 90 ]
                 , [ 50, 230, 0, 50 ]
                 );

  foreach my $test (@testdata) {
    is($c->getPowerLimited({ power => $test->[0], temperature => $test->[1] }), $test->[2]
                         , "power = $test->[0], temperature = $test->[1]"
    );
    $c->disableLimits;
    is($c->getPowerLimited({ power => $test->[0], temperature => $test->[1] }), $test->[3] // $test->[2]
                         , "power = $test->[0], temperature = $test->[1], limits off"
    );
    $c->enableLimits;

  }


};

done_testing();
