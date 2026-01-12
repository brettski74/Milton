#!/usr/bin/perl

use lib '.';

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;
use Cwd;
use Milton::Config;
use Milton::Config::Path qw(add_search_dir);

my $CWD = getcwd();

# Simple basic load with explicit path
my $cfg = Milton::Config->new("$CWD/t/testconfig.yaml");
is($cfg->{test1}, 'value1');
is($cfg->{test2}, 'value2');
is($cfg->{test3}, { colour => 'green', size => 'large' });

# Failed load due to file not existing on search path
$cfg = undef;
eval{
  $cfg = Milton::Config->new('testconfig.yaml');
};
ok(!defined $cfg);

subtest 'optional and empty constructor' => sub {
  my $empty = Milton::Config->new;
  isa_ok($empty, 'Milton::Config');
  is(scalar(%$empty), 0, 'empty config should be empty');

  is(Milton::Config->new('nonexistent.yaml', 1), undef, 'nonexistent.yaml should return undef');
};

# Simple basic load via search path
is([ add_search_dir('t') ], [ "$ENV{HOME}/.config/milton", "$ENV{MILTON_BASE}/share/milton/config", 't' ], 'search_path');
my $cfg2 = Milton::Config->new('testconfig.yaml');
is($cfg2->{test1}, 'value1');
is($cfg2->{test2}, 'value2');
is($cfg2->{test3}, { colour => 'green', size => 'large' });
is($cfg2->getPath, { filename => 'testconfig.yaml', fullpath => 't/testconfig.yaml' });
my $clone2 = $cfg2->clone;
is($clone2->{test1}, 'value1', 'Clone test1=value1');
is($clone2->{test2}, 'value2', 'Clone test2=value2');
is($clone2->{test3}, { colour => 'green', size => 'large' }, 'Clone test3={ colour => green, size => large }');
is($clone2->getPath, { filename => 'testconfig.yaml', fullpath => 't/testconfig.yaml' }, 'Clone root getPath');

# Test configFileExists method
note("Testing configFileExists method");
ok(Milton::Config->configFileExists('testconfig.yaml'), 'testconfig.yaml does exist in search path');
ok(Milton::Config->configFileExists("$CWD/t/testconfig.yaml"), 't/testconfig.yaml does exist with explicit path');
ok(!Milton::Config->configFileExists('nonexistent.yaml'), 'nonexistent.yaml does not exist');
ok(Milton::Config->configFileExists('command/test.yaml'), 'command/test.yaml does exist');
ok(!Milton::Config->configFileExists('command/are_you_serious.yaml'), 'command/are_you_serious.yaml does not exist');

subtest 'Environment variable expansion' => sub {
  no warnings 'uninitialized';

  my $env = Milton::Config->new('environment.yaml');

  is($env->{user}, $ENV{LOGNAME}, 'user');
  is($env->{logging}->{enabled}, 1, 'logging->enabled');
  is($env->{logging}->{filename}, $ENV{HOME} . '/.config/milton/milton.log', 'logging->filename');
  is($env->{logging}->{suffixed}, 'Hostname is ' . $ENV{HOSTNAME}, 'logging->suffixed');
  is($env->{logging}->{middle}, 'UID is ' . $ENV{UID} . ' you know', 'logging->middle');
  is($env->{logging}->{multi}, $ENV{LOGNAME} . ' and ' . $ENV{HOSTNAME} . ' and ' . $ENV{UID} . ' and ' . $ENV{USER}, 'logging->multi');
  is($env->{logging}->{undefined}, 'Undefined ' . $ENV{UNDEFINED} . ' Value', 'logging->undefined');

  is($env->{include}->{shell}, $ENV{SHELL}, 'include->shell');
  is($env->{include}->{message}, 'The process id of my shell (' . $ENV{SHELL} . ') is probably ' . $ENV{PPID}, 'include->message');
};

# Test findKey method
note("Testing findKey method");
subtest 'findKey method' => sub {
    # Test basic hash key existence
    is($cfg2->findKey('test1'), 'value1', 'findKey returns value for existing top-level key');
    is($cfg2->findKey('test2'), 'value2', 'findKey returns value for existing top-level key');
    is($cfg2->findKey('test3'), { colour => 'green', size => 'large' }, 'findKey returns value for existing hash key');
    
    # Test non-existent keys
    is($cfg2->findKey('nonexistent'), undef, 'findKey returns undef for non-existent top-level key');
    is($cfg2->findKey('test1', 'nonexistent'), undef, 'findKey returns undef for non-existent nested key');
    
    # Test nested hash access
    is($cfg2->findKey('test3', 'colour'), 'green', 'findKey returns value for existing nested hash key');
    is($cfg2->findKey('test3', 'size'), 'large', 'findKey returns value for existing nested hash key');
    is($cfg2->findKey('test3', 'nonexistent'), undef, 'findKey returns undef for non-existent nested hash key');
    
    # Test deep nesting
    is($cfg2->findKey('test3', 'colour'), 'green', 'findKey works with deep nesting');
    
    # Test with empty key list
    is($cfg2->findKey(), $cfg2, 'findKey with no keys returns the entire config');
    
    # Test with undef values
    my $cfg_with_undef = Milton::Config->new();
    $cfg_with_undef->{undef_key} = undef;
    is($cfg_with_undef->findKey('undef_key'), undef, 'findKey returns undef for key that exists but has undef value');
    
    # Test with array access (if we had arrays in the test config)
    # Since testconfig.yaml doesn't have arrays, let's create a test config with arrays
    my $array_cfg = Milton::Config->new();
    $array_cfg->{array_key} = ['item1', 'item2', 'item3'];
    $array_cfg->{nested} = {
        array => ['nested1', 'nested2', { 'nested-hash-key' => 'nested-hash-value' } ],
        hash => { key => 'value' }
    };
    
    is($array_cfg->findKey('array_key', 0), 'item1', 'findKey returns value for existing array index');
    is($array_cfg->findKey('array_key', 1), 'item2', 'findKey returns value for existing array index');
    is($array_cfg->findKey('array_key', 2), 'item3', 'findKey returns value for existing array index');
    is($array_cfg->findKey('array_key', 3), undef, 'findKey returns undef for non-existent array index');
    is($array_cfg->findKey('array_key', -1), 'item3', 'findKey returns undef for negative array index');
    
    # Test nested array access
    is($array_cfg->findKey('nested', 'array', 0), 'nested1', 'findKey returns value for existing nested array index');
    is($array_cfg->findKey('nested', 'array', 1), 'nested2', 'findKey returns value for existing nested array index');
    is($array_cfg->findKey('nested', 'array', 2), { 'nested-hash-key' => 'nested-hash-value' }, 'findKey returns value for existing nested array index');
    is($array_cfg->findKey('nested', 'array', 3), undef, 'findKey returns undef for non-existent nested array index');

    # Test mixed hash and array access
    is($array_cfg->findKey('nested', 'hash', 'key'), 'value', 'findKey works with mixed hash and array access');
    is($array_cfg->findKey('nested', 'array', 2, 'nested-hash-key'), 'nested-hash-value', 'hash-array-hash nesting'); 
    is($array_cfg->findKey('nested', 'array', 2, 'nested-has-key'), undef, 'hash-array-hash nesting'); 
    
    # Test with non-integer keys on arrays
    is($array_cfg->findKey('array_key', 'string'), undef, 'findKey returns undef for non-integer key on array');
    
    # Test with empty strings as keys
    $array_cfg->{''} = 'empty_key_value';
    is($array_cfg->findKey(''), 'empty_key_value', 'findKey works with empty string as key');
    
    # Test with zero as key
    $array_cfg->{0} = 'zero_key_value';
    is($array_cfg->findKey(0), 'zero_key_value', 'findKey works with zero as key');
    
};

# Merge another file into the config
$cfg2->merge('command/test.yaml', 'command', 'test');
is($cfg2->{command}->{test}->{'command-value-1'}, 100);
is($cfg2->{command}->{test}->{'command-value-2'}, 'red');
is($cfg2->getPath->{fullpath}, 't/testconfig.yaml');

# Merge into a non-existent path
$cfg2->merge('command/test.yaml', 'command', 'nonexistent');
is($cfg2->{command}->{nonexistent}->{'command-value-1'}, 100, 'command-value-1 should be added');
is($cfg2->{command}->{nonexistent}->{'command-value-2'}, 'red', 'command-value-2 should be added');
is($cfg2->getPath->{fullpath}, 't/testconfig.yaml');
is($cfg2->getPath('command', 'nonexistent')->{fullpath}, 't/command/test.yaml');

# Merge into a fully non-existent path
$cfg2->merge('command/test.yaml', 'crazy', 'path', 'that', 'does', 'not', 'exist');
is($cfg2->{crazy}->{path}->{that}->{does}->{not}->{exist}->{'command-value-1'}, 100, 'command-value-1 should be added');
is($cfg2->{crazy}->{path}->{that}->{does}->{not}->{exist}->{'command-value-2'}, 'red', 'command-value-2 should be added');
is($cfg2->getPath->{fullpath}, 't/testconfig.yaml');
is($cfg2->getPath('crazy', 'path', 'that', 'does', 'not', 'exist')->{fullpath}, 't/command/test.yaml');

# Verify path information is preserved throughout the hierarchy after cloning
$clone2 = $cfg2->clone;
is($clone2->getPath->{fullpath}, 't/testconfig.yaml', 'Clone root getPath again');
is($clone2->getPath('command', 'nonexistent')->{fullpath}, 't/command/test.yaml', 'Cloned command.nonexistent getPath');
is($clone2->getPath('crazy', 'path', 'that', 'does', 'not', 'exist')->{fullpath}, 't/command/test.yaml', 'Cloned crazy.path.that.does.not.exist getPath');

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
is($cfg2->getPath->{fullpath}, 't/testconfig.yaml');

# Test merging an empty file
$cfg2->merge('empty.yaml', 'command', 'test');
is($cfg2->{command}->{test}->{'command-value-1'}, 200, 'command-value-1 should be preserved');
is($cfg2->{command}->{test}->{'command-value-2'}, 'red', 'command-value-2 should be preserved');
is($cfg2->getPath->{fullpath}, 't/testconfig.yaml');

# Test merging a list item
$cfg2->merge('command/list_item.yaml', 'command', 'test', 'list', 1);
is($cfg2->{command}->{test}->{list}->[1]->{name}, 'item2', 'list item 2 should be preserved');
is($cfg2->{command}->{test}->{list}->[1]->{value}, 873, 'list item 2 should be overridden');
is($cfg2->{command}->{test}->{list}->[1]->{'added-value'}, 'always', 'list item 2 should have added-value');

# test merging at the root level
$cfg2->merge('root_merge.yaml');
is($cfg2->{test1}, 'value1', 'test1 should be preserved');
is($cfg2->{test2}, 'changed', 'test2 should be changed');
is($cfg2->{test3}->{color}, 'blue', 'test3->color should be blue');
is($cfg2->{test3}->{age}, 10, 'test3->age should be 10');
is($cfg2->{something}, 'here', 'something should be here');

# Test file include functionality
note("Testing file include functionality");

# Test basic include functionality
my $include_cfg = Milton::Config->new('include_base.yaml');
is($include_cfg->{app_name}, 'HP Controller', 'app_name');
is($include_cfg->{version}, '1.0.0', 'version');
is($include_cfg->{debug}, 1, 'debug');
is($include_cfg->{environment}, 'development', 'environment');
is($include_cfg->getPath->{fullpath}, 't/include_base.yaml');
is($include_cfg->getPath->{filename}, 'include_base.yaml');

# Test that included controller configuration is loaded
is($include_cfg->{controller}, D(), 'Controller configuration should be included');
is($include_cfg->{controller}->{thermal_constant}, 1.234, 'controller->thermal_constant');
is($include_cfg->{controller}->{thermal_offset}, 34.56, 'controller->thermal_offset');
is($include_cfg->{controller}->{reflow_profile}->[0]->{name}, 'preheat', 'controller->reflow_profile->1->name');
is($include_cfg->{controller}->{reflow_profile}->[0]->{duration}, 9, 'controller->reflow_profile->1->duration');
is($include_cfg->{controller}->{reflow_profile}->[0]->{target_temperature}, 99, 'controller->reflow_profile->1->target_temperature');
is($include_cfg->{controller}->{reflow_profile}->[1]->{name}, 'soak', 'controller->reflow_profile->2->name');
is($include_cfg->{controller}->{reflow_profile}->[1]->{duration}, 99, 'controller->reflow_profile->2->duration');
is($include_cfg->{controller}->{reflow_profile}->[1]->{target_temperature}, 169, 'controller->reflow_profile->2->target_temperature');

# Test that included interface configuration is loaded
is($include_cfg->{interface}, D(), 'Interface configuration should be included');
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
  $missing_cfg = Milton::Config->new('include_missing.yaml');
};
ok($@ =~ /non_existent_controller.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $missing_cfg);

# Test circular include detection
note("Testing circular include detection");
my $circular_cfg;
eval {
  $circular_cfg = Milton::Config->new('include_circular1.yaml');
};
ok($@ =~ /include_circular2.yaml/, 'Error message should be correct') || diag($@);
ok(!defined $circular_cfg);

# Test include with subdirectory
note("Testing include with subdirectory");
my $subdir_cfg = Milton::Config->new('include_subdir.yaml');
is($subdir_cfg->{test}, 'value', 'test');
is($subdir_cfg->{list}->[0], 'item 1', 'list 1');
is($subdir_cfg->{list}->[1], 'item 2', 'list 2');
is($subdir_cfg->{command}->{config}->{'command-value-1'}, 100, 'command-value-1');
is($subdir_cfg->{command}->{config}->{'command-value-2'}, 'red', 'command-value-2');
is($subdir_cfg->{controller}->{thermal_offset}, 34.56, 'controller->thermal_offset');
is($subdir_cfg->getPath->{fullpath}, 't/include_subdir.yaml');
is($subdir_cfg->getPath('controller')->{fullpath}, 't/controller.yaml');
is($subdir_cfg->getPath('command', 'config')->{fullpath}, 't/command/test.yaml');

done_testing;

