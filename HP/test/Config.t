#!/usr/bin/perl

use lib '.';
use Test2::V0;
use HP::Config;

# Simple basic load with explicit path
my $cfg = HP::Config->new('test/testconfig.yaml');
is($cfg->{test1}, 'value1');
is($cfg->{test2}, 'value2');
is($cfg->{test3}, { colour => 'green', size => 'large' });

# Failed load due to file not existing on search path
$cfg = undef;
eval{
  $cfg = HP::Config->new('testconfig.yaml');
};
ok(!defined $cfg);

# Simple basic load via search path
HP::Config::addSearchDir('test');
my $cfg = HP::Config->new('testconfig.yaml');
is($cfg->{test1}, 'value1');
is($cfg->{test2}, 'value2');
is($cfg->{test3}, { colour => 'green', size => 'large' });

done_testing();

