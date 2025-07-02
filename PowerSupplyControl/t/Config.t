#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Config;

# Simple basic load with explicit path
my $cfg = PowerSupplyControl::Config->new('t/testconfig.yaml');
is($cfg->{test1}, 'value1');
is($cfg->{test2}, 'value2');
is($cfg->{test3}, { colour => 'green', size => 'large' });

# Failed load due to file not existing on search path
$cfg = undef;
eval{
  $cfg = PowerSupplyControl::Config->new('testconfig.yaml');
};
ok(!defined $cfg);

# Simple basic load via search path
is([ PowerSupplyControl::Config->addSearchDir('t') ], [ '.', 't' ], 'searchPath');
my $cfg2 = PowerSupplyControl::Config->new('testconfig.yaml');
is($cfg2->{test1}, 'value1');
is($cfg2->{test2}, 'value2');
is($cfg2->{test3}, { colour => 'green', size => 'large' });

# Test configFileExists method
note("Testing configFileExists method");
ok(PowerSupplyControl::Config->configFileExists('testconfig.yaml'), 'testconfig.yaml does exist in search path');
ok(PowerSupplyControl::Config->configFileExists('t/testconfig.yaml'), 't/testconfig.yaml does exist with explicit path');
ok(!PowerSupplyControl::Config->configFileExists('nonexistent.yaml'), 'nonexistent.yaml does not exist');
ok(PowerSupplyControl::Config->configFileExists('command/test.yaml'), 'command/test.yaml does exist');
ok(!PowerSupplyControl::Config->configFileExists('command/are_you_serious.yaml'), 'command/are_you_serious.yaml does not exist');

# Merge another file into the config
$cfg2->merge('command/test.yaml', 'command', 'test');
is($cfg2->{command}->{test}->{'command-value-1'}, 100);
is($cfg2->{command}->{test}->{'command-value-2'}, 'red');

# Test merging with pre-existing keys (deep merge)
note("Testing merge with pre-existing keys");
$cfg2->merge('command/override.yaml', 'command', 'test');
is($cfg2->{command}->{test}->{'command-value-1'}, 200, 'command-value-1 should be overridden');
is($cfg2->{command}->{test}->{'command-value-2'}, 'red', 'command-value-2 should be preserved');
is($cfg2->{command}->{test}->{'command-value-3'}, 'blue', 'command-value-3 should be added');
is($cfg2->{command}->{test}->{nested}->{'inner-value'}, 42, 'nested structure should be merged');
is($cfg2->{command}->{test}->{list}->[0]->{name}, 'item1', 'list item 1 should be preserved');
is($cfg2->{command}->{test}->{list}->[0]->{value}, 100, 'list item 1 should be preserved');
is($cfg2->{command}->{test}->{list}->[1]->{name}, 'item2', 'list item 2 should be preserved');
is($cfg2->{command}->{test}->{list}->[1]->{value}, 200, 'list item 2 should be preserved');
is($cfg2->{command}->{test}->{list}->[2]->{name}, 'item3', 'list item 3 should be preserved');
is($cfg2->{command}->{test}->{list}->[2]->{value}, 300, 'list item 3 should be preserved');
is($cfg2->{command}->{test}->{list}->[3]->{name}, 'item4', 'list item 4 should be preserved');
is($cfg2->{command}->{test}->{list}->[3]->{value}, 400, 'list item 4 should be preserved');

# Test merging an empty file
$cfg2->merge('empty.yaml', 'command', 'test');
is($cfg2->{command}->{test}->{'command-value-1'}, 200, 'command-value-1 should be preserved');
is($cfg2->{command}->{test}->{'command-value-2'}, 'red', 'command-value-2 should be preserved');

# Test merging a list item
$cfg2->merge('command/list_item.yaml', 'command', 'test', 'list', 1);
is($cfg2->{command}->{test}->{list}->[1]->{name}, 'item2', 'list item 2 should be preserved');
is($cfg2->{command}->{test}->{list}->[1]->{value}, 873, 'list item 2 should be overridden');
is($cfg2->{command}->{test}->{list}->[1]->{'added-value'}, 'always', 'list item 2 should have added-value');

# Test file include functionality
note("Testing file include functionality");

# Test basic include functionality
my $include_cfg = PowerSupplyControl::Config->new('include_base.yaml');
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
  $missing_cfg = PowerSupplyControl::Config->new('include_missing.yaml');
};
ok($@ =~ /non_existent_controller.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $missing_cfg);

# Test circular include detection
note("Testing circular include detection");
my $circular_cfg;
eval {
  $circular_cfg = PowerSupplyControl::Config->new('include_circular1.yaml');
};
ok($@ =~ /include_circular2.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $circular_cfg);



done_testing();

