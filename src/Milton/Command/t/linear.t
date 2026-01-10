#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use lib '.';

use Test2::V0;
use Test2::Tools::Compare qw(hash field etc);

use Milton::Command::linear;
use Milton::Config::Path qw(clear_search_path add_search_dir);
use Path::Tiny qw(path);

my $EPS = 0.0005;

clear_search_path;
add_search_dir(path(__FILE__)->realpath->parent->stringify);

subtest 'linear reflow command' => sub {
  my $command = Milton::Command::linear->new(undef, undef, undef, 'nopower');

  my $tf = $command->buildTransferFunction;
  is($tf->estimate(100), 20, 'First data point is 100,20');
  is($tf->estimate(153.5), 40, 'Second data point is 153.5,40');
  is($tf->estimate(195.6), 60, 'Third data point is 195.6,60');
  is($tf->estimate(224.7), 75, 'Fourth data point is 224.7,75');

  my $profile = $command->buildProfile;
  my $stages = $profile->{stages};
  is ($stages->[0]
   , hash { field name => 'preheat';
            field temperature => 100;
            field duration => 100;
            field power => float(24, tolerance => $EPS);
            etc();
          }   
   , 'Preheat profile stage complete'
   );
  is ($stages->[1]
   , hash { field name => 'soak';
            field temperature => 160;
            field duration => 120;
            field power => float(51.705, tolerance => $EPS);
            etc();
          }
   , 'Soak profile stage complete'
   );
  is ($stages->[2]
   , hash { field name => 'reflow';
            field temperature => 215;
            field duration => 60;
            field power => float(84, tolerance => $EPS);
            etc();
          }
   , 'Reflow profile stage complete'
   );
  is ($stages->[3]
   , hash { field name => 'dwell';
            field temperature => 215;
            field duration => 20;
            field power => float(70, tolerance => $EPS);
            etc();
          }
   , 'Dwell profile stage complete'
   );
  is ($stages->[4]
   , hash { field name => 'cool';
            field temperature => 100;
            field duration => 120;
            field power => float(16, tolerance => $EPS);
            etc();
          }
   , 'Cool profile stage complete'
   );

};

done_testing;