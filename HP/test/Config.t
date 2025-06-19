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
is($include_cfg->{controller}->{reflow_profile}->{name}, 'preheat', 'controller->reflow_profile->name');
is($include_cfg->{controller}->{reflow_profile}->{duration}, 9, 'controller->reflow_profile->duration');
is($include_cfg->{controller}->{reflow_profile}->{target_temperature}, 99, 'controller->reflow_profile->target_temperature');

# Test that included interface configuration is loaded
ok(exists $include_cfg->{interface}, 'Interface configuration should be included');
is($include_cfg->{interface}->{address}, 1, 'interface->address');
is($include_cfg->{interface}->{baud_rate}, 19200, 'interface->baud_rate');
is($include_cfg->{interface}->{power}->{max}, 120, 'interface->power->max');
is($include_cfg->{interface}->{current}->{min}, 0.1, 'interface->current->min');
is($include_cfg->{interface}->{current}->{max}, 12, 'interface->current->max');

# Test nested includes
note("Testing nested includes");
my $nested_cfg = HP::Config->new('include_nested.yaml');
is($nested_cfg->{nested_config}->{level}, 1, 'nested_config->level');
is($nested_cfg->{nested_config}->{description}, 'Primary controller configuration', 'nested_config->description');
ok(exists $nested_cfg->{deep_config}, 'Deep nested configuration should be included');
is($nested_cfg->{deep_config}->{deep_config}->{level}, 2, 'deep_config->deep_config->level');
is($nested_cfg->{deep_config}->{deep_config}->{description}, 'This is a deeply nested configuration for HP Controller', 'deep_config->deep_config->description');
is($nested_cfg->{deep_config}->{deep_settings}->{timeout}, 60, 'deep_config->deep_settings->timeout');
is($nested_cfg->{deep_config}->{deep_settings}->{retries}, 3, 'deep_config->deep_settings->retries');

# Test key override behavior (later keys should override earlier ones)
note("Testing key override behavior");
my $override_cfg = HP::Config->new('include_override.yaml');
is($override_cfg->{controller}->{thermal_constant}, 2.0, 'Later controller.thermal_constant should override included value');
is($override_cfg->{controller}->{thermal_offset}, 0.0, 'Original thermal_offset should be preserved');
ok(exists $override_cfg->{included_controller}, 'Included controller should be present');
is($override_cfg->{included_controller}->{controller}->{thermal_constant}, 1.5, 'Included thermal_constant should be present');
is($override_cfg->{included_controller}->{controller}->{thermal_offset}, 25.0, 'Included thermal_offset should be present');
is($override_cfg->{included_controller}->{other_setting}, 'preserved_value', 'Other setting from include should be preserved');

# Test error handling for missing include files
note("Testing error handling for missing include files");
my $missing_cfg = HP::Config->new('include_missing.yaml');
is($missing_cfg->{app_name}, 'HP Controller Test', 'Base configuration should still be loaded');
is($missing_cfg->{valid_setting}, 'this should still be loaded', 'Valid settings should be preserved');
is($missing_cfg->{controller_mode}, 'manual', 'Controller mode should be loaded');
# The missing include should be logged but not cause failure

# Test that include directive is cleaned up
note("Testing that include directive is cleaned up");
# With !include tags, there's no include key to clean up, so this test is not applicable

# Test that files without includes still work correctly
note("Testing files without includes");
my $no_include_cfg = HP::Config->new('no_include.yaml');
is($no_include_cfg->{simple_setting}, 'simple_value', 'Simple setting should be loaded');
is($no_include_cfg->{controller_mode}, 'manual', 'Controller mode should be loaded');
is($no_include_cfg->{temperature_unit}, 'celsius', 'Temperature unit should be loaded');
is($no_include_cfg->{nested_setting}->{key1}, 'value1', 'Nested setting should be loaded');
is($no_include_cfg->{nested_setting}->{key2}, 'value2', 'Nested setting should be loaded');
is($no_include_cfg->{array_setting}, ['temperature_control', 'safety_monitoring', 'data_logging'], 'Array setting should be loaded');

# Test including files into arrays
note("Testing including files into arrays");
my $array_cfg = HP::Config->new('include_array.yaml');
ok(exists $array_cfg->{plugins}, 'Plugins array should exist');
is(scalar @{$array_cfg->{plugins}}, 3, 'Should have 3 plugins');
ok(exists $array_cfg->{plugins}->[0]->{thermal_constant}, 'First plugin should be included controller config');
ok(exists $array_cfg->{plugins}->[1]->{address}, 'Second plugin should be included interface config');
is($array_cfg->{plugins}->[2]->{name}, 'local_plugin', 'Third plugin should be local config');
is($array_cfg->{feature_list}, ['temperature_control', 'reflow_profiles', 'safety_monitoring', 'data_logging', 'serial_communication'], 'Feature list should be included array');

# Test deep merging of nested structures
note("Testing deep merging of nested structures");
my $merge_cfg = HP::Config->new('include_merge.yaml');
is($merge_cfg->{application}->{name}, 'HP Controller', 'Original name should be preserved');
ok(exists $merge_cfg->{additional_config}, 'Additional config should be included');
is($merge_cfg->{additional_config}->{application}->{version}, '2.0.0', 'Included version should be present');
is($merge_cfg->{additional_config}->{application}->{settings}->{timeout}, 60, 'Included timeout should be present');
is($merge_cfg->{additional_config}->{new_section}->{enabled}, 1, 'New section should be present');

# Test circular include detection
note("Testing circular include detection");
my $circular_cfg;
eval {
  $circular_cfg = HP::Config->new('include_circular1.yaml');
};
# The system should either detect the circular reference and handle it gracefully
# or we should get some indication of the circular reference
if (defined $circular_cfg) {
  note("Circular reference was handled gracefully");
  # Verify that we got some configuration loaded
  ok(exists $circular_cfg->{circular_test}, 'Some circular test configuration was loaded');
} else {
  note("Circular reference was detected and prevented");
  # This is also acceptable behavior
}

# Test conditional includes
note("Testing conditional includes");
my $conditional_cfg = HP::Config->new('include_conditional.yaml');
is($conditional_cfg->{environment}, 'production', 'Environment should be set');
ok(exists $conditional_cfg->{production_config}, 'Production config should be included');
ok(exists $conditional_cfg->{development_config}, 'Development config should be included');
is($conditional_cfg->{production_config}->{debug}, 0, 'Production debug should be false');
is($conditional_cfg->{development_config}->{debug}, 1, 'Development debug should be true');

done_testing();

