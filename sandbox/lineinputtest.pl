#!/usr/bin/perl

use lib '.';
use lib '..';

use strict;
use warnings qw(all -uninitialized);

use HP::EventLoop;
use HP::t::MockEventLoop;
use HP::Command::linebuffertest;
use HP::Config;

system 'rm -f line_input_test.*.csv';

my $config = { logging => { enabled => 'true'
                          , tee => 'true'
                          , filename => 'line_input_test.%d.csv'
                          , columns => [ { key => 'now', format => '.3f' }
                                       , { key => 'event' }
                                       , { key => 'key' }
                                       , { key => 'line' }
                                       ]
                          }
             , period => 2
             , interface => { package => 'HP::t::MockInterface' }
             , controller => { package => 'HP::t::MockController' }
             , command => { linebuffertest => {} }
             };

bless $config, 'HP::Config';
#my $evl = HP::t::MockEventLoop->new($config, 'linebuffertest');
my $evl = HP::EventLoop->new($config, 'linebuffertest');

$evl->run;

exit(0);

