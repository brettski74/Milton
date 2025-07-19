#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use PowerSupplyControl::Command::reflow;
use PowerSupplyControl::t::MockInterface;
use PowerSupplyControl::t::MockController;

my $EPS = 0.000001;

subtest 'timerEvent' => sub {
  my $config = { profile => [ { name => 'preheat', temperature => 100, seconds => 30 }
                            , { name => 'soak', temperature => 175, seconds => 120 }
                            , { name => 'reflow', temperature => 205, seconds => 30 }
                            , { name => 'hold', temperature => 205, seconds => 10 }
                            , { name => 'cool', temperature => 100, seconds => 120 }
                            ]
               };

  my $interface = PowerSupplyControl::t::MockInterface->new;
  my $controller = PowerSupplyControl::t::MockController->new;

  $interface->setMockData( [ qw(now current voltage power resistance) ]
                         , [ 0, 9.6, 12, 115.2, 1.25 ]
                         );

  my $cmd = PowerSupplyControl::Command::reflow->new($config, $interface, $controller);

  my $status = { temperature => 25 };
  $cmd->preprocess($status);
  is($status->{ambient}, 25, 'ambient');
  is($cmd->{ambient}, 25, 'cmd ambient');

  $status = { now => 0
            , temperature => 25
            , period => 1.5
            , voltage => 2
            , current => 2
            , power => 4
            , resistance => 1
            , ambient => 25
            , event => 'timerEvent'
            };

  my $rc = $cmd->timerEvent($status);

  is($rc, T(), 'cmd returns true for early timerEvent');
  is($status->{then}, 1.5, 'then');
  is($status->{'then-temperature'}, float(28.75, tolerance => $EPS), 'target-temperature');
  is($status->{'set-power'}, 23.2, 'set-power');
  is($status->{stage}, 'preheat', 'stage');

  $status = { now => 310
            , temperature => 25
            , period => 1.5
            , voltage => 2
            , current => 2
            , power => 4
            , resistance => 1
            , ambient => 25
            , event => 'timerEvent'
            };

  $rc = $cmd->timerEvent($status);
  is($rc, F(), 'cmd returns false for final timerEvent');
};


done_testing;