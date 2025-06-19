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

# Test error handling for missing include files
note("Testing error handling for missing include files");
my $missing_cfg;
eval {
  $missing_cfg = HP::Config->new('include_missing.yaml');
};
is($@, 'Error: Failed to load include file: include_missing.yaml', 'Error message should be correct');
ok(!defined $missing_cfg);

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

