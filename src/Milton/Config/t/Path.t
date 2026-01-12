#!/usr/bin/perl

use lib '.';

use strict;
use warnings qw(all -uninitialized);

use Path::Tiny qw(path);

use Test2::V0;
use Milton::Config::Path qw(add_search_dir clear_search_path search_path resolve_file_path unresolve_file_path);

my $TEST_DIR = path(__FILE__)->realpath->parent;

clear_search_path();
add_search_dir($TEST_DIR->stringify);
add_search_dir('/opt/milton/share/milton/config');

subtest 'unresolve_file_path' => sub {
  my $path = $TEST_DIR->child('testconfig.yaml')->stringify;
  is(unresolve_file_path($path), 'testconfig.yaml', 'unresolve_file_path');

  $path = $TEST_DIR->child('command/profile/standard.yaml')->stringify;
  is(unresolve_file_path($path), 'command/profile/standard.yaml', 'unresolve '. $path);

  $path = '/opt/milton/share/milton/config/command/linear/standard.yaml';
  is(unresolve_file_path($path), 'command/linear/standard.yaml', 'unresolve '. $path);
};

done_testing();