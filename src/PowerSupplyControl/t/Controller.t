#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use lib qw(.);

use Test2::V0;

use PowerSupplyControl::Controller;

subtest 'getAmbient' => sub {
  my $status = {};
  my $c = PowerSupplyControl::Controller->new();

  is($c->getAmbient($status), 25);
  is($status->{ambient}, 25);

  $status = { temperature => 26 };
  is($c->getAmbient($status), 26);
  is($status->{ambient}, 26);

  $status = { temperature => 24 };
  is($c->getAmbient($status), 24);
  is($status->{ambient}, 24);

  $status = { temperature => 19 };
  is($c->getAmbient($status), 19);
  is($status->{ambient}, 19);

  $status = { temperature => 24, 'device-temperature' => 25, 'device-ambient' => 24.1 };
  is($c->getAmbient($status), 24);
  is($status->{ambient}, 24);

  $status = { temperature => 24.4, 'device-temperature' => 25, 'device-ambient' => 24.1 };
  is($c->getAmbient($status), 24.1);
  is($status->{ambient}, 24.1);

  $status = { temperature => 29.6, 'device-temperature' => 26.1, 'device-ambient' => 26.7 };
  is($c->getAmbient($status), 26.1);
  is($status->{ambient}, 26.1);

  $status = { temperature => 24.4, 'device-temperature' => 25, 'device-ambient' => 19.6 };
  is($c->getAmbient($status), 19.6);
  is($status->{ambient}, 19.6);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, 'device-ambient' => 27.1 };
  is($c->getAmbient($status), 27.1);
  is($status->{ambient}, 27.1);

  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 25);
  is($status->{ambient}, 25);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, ambient => 27.1 };
  is($c->getAmbient($status), 27.1);
  is($status->{ambient}, 27.1);

  $status = { temperature => 37.5, 'device-temperature' => 33.3, ambient => 31 };
  is($c->getAmbient($status), 31);
  is($status->{ambient}, 31);

  $c->setAmbient(27.3);
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 27.3);
  is($status->{ambient}, 27.3);

  $c = PowerSupplyControl::Controller->new({ambient => 27.6});
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 27.6);
  is($status->{ambient}, 27.6);

  $c->setAmbient(28.2);
  $status = { temperature => 37.5, 'device-temperature' => 33.3 };
  is($c->getAmbient($status), 28.2);
  is($status->{ambient}, 28.2);

};

done_testing();