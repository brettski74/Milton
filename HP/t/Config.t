#!/usr/bin/perl

use lib '.';
use Test2::V0;
use HP::Config;

# Simple basic load with explicit path
my $cfg = HP::Config->new('t/testconfig.yaml');
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
HP::Config::addSearchDir('t');
my $cfg2 = HP::Config->new('testconfig.yaml');
is($cfg2->{test1}, 'value1');
is($cfg2->{test2}, 'value2');
is($cfg2->{test3}, { colour => 'green', size => 'large' });

# Test file include functionality
note("Testing file include functionality");

# Test basic include functionality
my $include_cfg = HP::Config->new('include_base.yaml');
is($include_cfg->{app_name}, 'HP Controller', 'app_name');
is($include_cfg->{version}, '1.0.0', 'version');
is($include_cfg->{debug}, 1, 'debug');
is($include_cfg->{environment}, 'development', 'environment');

# Test that included controller configuration is loaded
ok(exists $include_cfg->{controller}, 'Controller configuration should be included');
is($include_cfg->{controller}->{thermal_constant}, 1.234, 'controller->thermal_constant');
is($include_cfg->{controller}->{thermal_offset}, 34.56, 'controller->thermal_offset');
is($include_cfg->{controller}->{reflow_profile}->[0]->{name}, 'preheat', 'controller->reflow_profile->1->name');
is($include_cfg->{controller}->{reflow_profile}->[0]->{duration}, 9, 'controller->reflow_profile->1->duration');
is($include_cfg->{controller}->{reflow_profile}->[0]->{target_temperature}, 99, 'controller->reflow_profile->1->target_temperature');
is($include_cfg->{controller}->{reflow_profile}->[1]->{name}, 'soak', 'controller->reflow_profile->2->name');
is($include_cfg->{controller}->{reflow_profile}->[1]->{duration}, 99, 'controller->reflow_profile->2->duration');
is($include_cfg->{controller}->{reflow_profile}->[1]->{target_temperature}, 169, 'controller->reflow_profile->2->target_temperature');

# Test that included interface configuration is loaded
ok(exists $include_cfg->{interface}, 'Interface configuration should be included');
is($include_cfg->{interface}->{address}, 1, 'interface->address');
is($include_cfg->{interface}->{baud_rate}, 19200, 'interface->baud_rate');
is($include_cfg->{interface}->{power}->{max}, 120, 'interface->power->max');
is($include_cfg->{interface}->{current}->{min}, 0.1, 'interface->current->min');
is($include_cfg->{interface}->{current}->{max}, 12, 'interface->current->max');


# Test clone method for hashes
my $cloned_hash = $include_cfg->clone('controller');
is($cloned_hash->{thermal_constant}, 1.234, 'cloned_hash->thermal_constant');
is($cloned_hash->{thermal_offset}, 34.56, 'cloned_hash->thermal_offset');
is($cloned_hash->{reflow_profile}->[0]->{name}, 'preheat', 'cloned_hash->reflow_profile->1->name');
is($cloned_hash->{reflow_profile}->[0]->{duration}, 9, 'cloned_hash->reflow_profile->1->duration');
is($cloned_hash->{reflow_profile}->[0]->{target_temperature}, 99, 'cloned_hash->reflow_profile->1->target_temperature');
is($cloned_hash->{reflow_profile}->[1]->{name}, 'soak', 'cloned_hash->reflow_profile->2->name');
is($cloned_hash->{reflow_profile}->[1]->{duration}, 99, 'cloned_hash->reflow_profile->2->duration');

#Test clone method for arrays
my $cloned_array = $include_cfg->clone('controller', 'reflow_profile');
is($cloned_array->[0]->{name}, 'preheat', 'cloned_array->1->name');
is($cloned_array->[0]->{duration}, 9, 'cloned_array->1->duration');
is($cloned_array->[0]->{target_temperature}, 99, 'cloned_array->1->target_temperature');
is($cloned_array->[1]->{name}, 'soak', 'cloned_array->2->name');
is($cloned_array->[1]->{duration}, 99, 'cloned_array->2->duration');

# Test clone method for a hash within an array
my $cloned_hash_in_array = $include_cfg->clone('controller', 'reflow_profile', 1);
is($cloned_hash_in_array->{name}, 'soak', 'cloned_hash_in_array->name');
is($cloned_hash_in_array->{duration}, 99, 'cloned_hash_in_array->duration');
is($cloned_hash_in_array->{target_temperature}, 169, 'cloned_hash_in_array->target_temperature');

# Test error handling for missing include files
note("Testing error handling for missing include files");
my $missing_cfg;
eval {
  $missing_cfg = HP::Config->new('include_missing.yaml');
};
ok($@ =~ /non_existent_controller.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $missing_cfg);

# Test circular include detection
note("Testing circular include detection");
my $circular_cfg;
eval {
  $circular_cfg = HP::Config->new('include_circular1.yaml');
};
ok($@ =~ /include_circular2.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $circular_cfg);

done_testing();

