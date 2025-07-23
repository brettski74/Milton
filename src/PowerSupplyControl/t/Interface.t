#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use Test2::V0;
use PowerSupplyControl::Interface;
use PowerSupplyControl::t::MockInterface;
use Readonly;

Readonly my $EPS => 0.000001;

# Return an array that produces simple offsets from the actual value for calibration tests.
sub offset_estimator {
  my ($requested_offset, $sampled_offset) = @_;

  return [ { actual => 1, requested => 1 + $requested_offset, sampled => 1 + $sampled_offset }
         , { actual => 0, requested => $requested_offset, sampled => $sampled_offset }
         ];

}

# Test constructor
subtest 'Constructor' => sub {
  my $config = {
      voltage => { minimum => 1, maximum => 30 },
      current => { minimum => 0.1, maximum => 10, measurable => 1 },
      power => { minimum => 10, maximum => 120 }
  };
    
  my $interface = PowerSupplyControl::t::MockInterface->new($config);
  isa_ok($interface, 'PowerSupplyControl::t::MockInterface');
  isa_ok($interface, 'PowerSupplyControl::Interface');
  
  # Test that the interface was properly initialized abd the MockInterface class didn't do anything stupid like overwriting configuration data with a row counter.
  is($interface->{voltage}->{minimum}, 1, 'voltage minimum set correctly');
  is($interface->{voltage}->{maximum}, 30, 'voltage maximum set correctly');
  is($interface->{current}->{minimum}, 0.1, 'current minimum set correctly');
  is($interface->{current}->{maximum}, 10, 'current maximum set correctly');
  is($interface->{power}->{minimum}, 10, 'power minimum set correctly');
  is($interface->{power}->{maximum}, 120, 'power maximum set correctly');
};

# Test _buildCalibration method
subtest '_buildCalibration method' => sub {
  my $interface = PowerSupplyControl::t::MockInterface->new();
  ok(!exists $interface->{'voltage-requested'}, 'no calibration, no voltage estimators');
  ok(!exists $interface->{'voltage-output'}, 'no calibration, no voltage estimators');
  ok(!exists $interface->{'voltage-setpoint'}, 'no calibration, no voltage estimators');
  ok(!exists $interface->{'current-requested'}, 'no calibration, no current estimators');
  ok(!exists $interface->{'current-output'}, 'no calibration, no current estimators');
  ok(!exists $interface->{'current-setpoint'}, 'no calibration, no current estimators');

  # Test with real-ish calibration data
  my $config = { calibration => { current => [ { requested => 1.5, sampled => 1, actual => 2 }
                                             , { requested => 3, sampled => 2, actual => 5 }
                                             ]
                                , voltage => [ { requested => 4, sampled => 1, actual => 5 }
                                             , { requested => 5, sampled => 2, actual => 6 }
                                             ]
                                }
               };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  ok(exists $interface->{'voltage-requested'}, 'voltage-requested calibration built');
  ok(exists $interface->{'voltage-output'}, 'voltage-output calibration built');
  ok(exists $interface->{'voltage-setpoint'}, 'voltage-setpoint calibration built');
  ok(exists $interface->{'current-requested'}, 'current-requested calibration built');
  ok(exists $interface->{'current-output'}, 'current-output calibration built');
  ok(exists $interface->{'current-setpoint'}, 'current-setpoint calibration built');

  # Test with partial calibration data
  $config = { calibration => { current => [ { requested => 1.5, actual => 2 }
                                          , { actual => 5 }
                                          ]
                             , voltage => [ { requested => 4, actual => 5 }
                                          , { requested => 5, sampled => 2, actual => 6 }
                                          , { sampled => 1, actual => 4 }
                                          ]
                             }
            };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  ok(exists $interface->{'voltage-requested'}, 'voltage-requested calibration built');
  ok(exists $interface->{'voltage-output'}, 'voltage-output calibration built');
  ok(exists $interface->{'voltage-setpoint'}, 'voltage-setpoint calibration built');
  ok(exists $interface->{'current-requested'}, 'current-requested calibration built');
  ok(!exists $interface->{'current-output'}, 'current-output calibration built');
  ok(exists $interface->{'current-setpoint'}, 'current-setpoint calibration built');
};

# Test poll method
subtest 'poll method' => sub {
  my $interface = PowerSupplyControl::t::MockInterface->new();
    
  # Set mock output values
  $interface->setMockOutput(12.5, 2.1, 1);
    
  # Test poll without status parameter
  my $status = $interface->poll();
  is($status->{voltage}, 12.5, 'poll returns correct voltage');
  is($status->{current}, 2.1, 'poll returns correct current');
  is($status->{power}, 26.25, 'poll calculates power correctly');
  is($status->{resistance}, 5.95238095238095, 'poll calculates resistance correctly');
    
  # Test poll with existing status parameter
  my $existing_status = { existing_key => 'existing_value' };
  my $result = $interface->poll($existing_status);
  is($result, $existing_status, 'poll returns the passed status hash');
  is($existing_status->{voltage}, 12.5, 'poll updates voltage in existing status');
  is($existing_status->{current}, 2.1, 'poll updates current in existing status');
  is($existing_status->{existing_key}, 'existing_value', 'poll preserves existing keys');
    
  # Test poll with zero current (no resistance calculation)
  $interface->setMockOutput(12.5, 0, 1);
  $status = $interface->poll();
  is($status->{voltage}, 12.5, 'poll returns correct voltage with zero current');
  is($status->{current}, 0, 'poll returns correct current');
  is($status->{power}, 0, 'poll calculates power correctly with zero current');
  ok(!exists $status->{resistance}, 'poll does not calculate resistance with zero current');
  
  # Test poll count tracking
  is($interface->{poll_count}, 3, 'poll count is tracked correctly');

  # Test calibrated polling
  my $config = { calibration => { current => [ { requested => 2, sampled => 1, actual => 3 }
                                             , { requested => 3, sampled => 2, actual => 4 }
                                             ]
                                , voltage => [ { requested => 4, sampled => 1, actual => 5 }
                                             , { requested => 5, sampled => 2, actual => 6 }
                                             ]
                                }
               };
  $interface = PowerSupplyControl::t::MockInterface->new($config);

  # Set mock output
  $interface->setMockOutput(12.5, 4.1, 1);

  # Test poll with calibration
  $status = $interface->poll();
  is($status->{voltage}, 16.5, 'poll returns correct voltage');
  is($status->{current}, 6.1, 'poll returns correct current');
  is($status->{power}, 100.65, 'poll calculates power correctly');
  is($status->{resistance}, float(2.70491803278689, tolerance => $EPS), 'poll calculates resistance correctly');
};

# Test getVoltageSetPoint method
subtest 'getVoltageSetPoint method' => sub {
  my $config = { 'mock-voltage-setpoint' => 15.0
               , 'mock-current-setpoint' => 3.0
               };
  my $interface = PowerSupplyControl::t::MockInterface->new($config);
    
  # Test scalar context
  my $voltage = $interface->getVoltageSetPoint();
  is($voltage, 15.0, 'getVoltageSetPoint returns correct voltage in scalar context');
    
  # Test list context
  my ($cooked, $raw) = $interface->getVoltageSetPoint();
  is($cooked, 15.0, 'getVoltageSetPoint returns correct cooked voltage in list context');
  is($raw, 15.0, 'getVoltageSetPoint returns correct raw voltage in list context');
    
  # Test with some real-ish calibration data
  $config = { calibration => { voltage => [ { requested => 4, sampled => 1, actual => 5 }
                                          , { requested => 5, sampled => 2, actual => 6 }
                                          ]
                             }
            , 'mock-voltage-setpoint' => 12.1
            };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  $voltage = $interface->getVoltageSetPoint;
  is($voltage, 13.1, 'getVoltageSetPoint returns correct voltage with calibration');

  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 13.1, 'getVoltageSetPoint returns correct cooked voltage with calibration');
  is($raw, 12.1, 'getVoltageSetPoint returns correct raw voltage with calibration');
};

# Test getCurrentSetPoint method
subtest 'getCurrentSetPoint method' => sub {
  my $config = { 'mock-voltage-setpoint' => 14.0
               , 'mock-current-setpoint' => 5.0
               };
  my $interface = PowerSupplyControl::t::MockInterface->new($config);
    
  # Test scalar context
  my $current = $interface->getCurrentSetPoint();
  is($current, 5.0, 'getCurrentSetPoint returns correct current in scalar context');
    
  # Test list context
  my ($cooked, $raw) = $interface->getCurrentSetPoint();
  is($cooked, 5.0, 'getCurrentSetPoint returns correct cooked current in list context');
  is($raw, 5.0, 'getCurrentSetPoint returns correct raw current in list context');

  # Test current setpoint with calibration
  $config = { 'mock-current-setpoint' => 5.2
            , 'calibration' => { current => [ { requested => 1.5, sampled => 1, actual => 2 }
                                            , { requested => 3, sampled => 2, actual => 5 }
                                            ]
                             }
            };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  $current = $interface->getCurrentSetPoint();
  is($current, 9.4, 'getCurrentSetPoint returns correct current with calibration');

  ($cooked, $raw) = $interface->getCurrentSetPoint();
  is($cooked, 9.4, 'getCurrentSetPoint returns correct cooked current with calibration');
  is($raw, 5.2, 'getCurrentSetPoint returns correct raw current with calibration');
};

# Test getOutputVoltage method
subtest 'getOutputVoltage method' => sub {
  my $config = { 'mock-output-voltage' => 12.5
               , 'mock-output-current' => 2.1
               , 'mock-on-state' => 1
               , 'mock-voltage-setpoint' => 12.47
               , 'mock-current-setpoint' => 2.09
               };
  my $interface = PowerSupplyControl::t::MockInterface->new($config);
    
  # Test scalar context
  my $voltage = $interface->getOutputVoltage();
  is($voltage, 12.5, 'getOutputVoltage returns correct voltage in scalar context');
    
  # Test list context
  my ($cooked_voltage, $raw_voltage) = $interface->getOutputVoltage();
  is($cooked_voltage, 12.5, 'getOutputVoltage returns correct cooked voltage in list context');
  is($raw_voltage, 12.5, 'getOutputVoltage returns correct raw voltage in list context');

  # Test with some real-ish calibration data
  $config = { 'mock-output-voltage' => 12.5
            , 'mock-output-current' => 2.1
            , 'mock-on-state' => 1
            , 'mock-voltage-setpoint' => 12.47
            , 'mock-current-setpoint' => 2.09
            , 'calibration' => { voltage => [ { requested => 4, sampled => 1, actual => 5 }
                                          , { requested => 5, sampled => 2, actual => 6 }
                                          ]
                             }
            };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  $voltage = $interface->getOutputVoltage();
  is($voltage, 16.5, 'getOutputVoltage returns correct voltage with calibration');

  ($cooked_voltage, $raw_voltage) = $interface->getOutputVoltage();
  is($cooked_voltage, 16.5, 'getOutputVoltage returns correct cooked voltage with calibration');
  is($raw_voltage, 12.5, 'getOutputVoltage returns correct raw voltage with calibration');
};

# Test getOutputCurrent method
subtest 'getOutputCurrent method' => sub {
  my $config = { 'mock-output-voltage' => 12.5
               , 'mock-output-current' => 2.1
               , 'mock-on-state' => 1
               , 'mock-voltage-setpoint' => 12.47
               , 'mock-current-setpoint' => 2.09
               };
  my $interface = PowerSupplyControl::t::MockInterface->new($config);
    
  # Test scalar context
  my $current = $interface->getOutputCurrent();
  is($current, 2.1, 'getOutputCurrent returns correct current in scalar context');
    
  # Test list context
  my ($cooked_current, $raw_current) = $interface->getOutputCurrent();
  is($cooked_current, 2.1, 'getOutputCurrent returns correct cooked current in list context');
  is($raw_current, 2.1, 'getOutputCurrent returns correct raw current in list context');

  # Test with some real-ish calibration data
  $config = { 'mock-output-voltage' => 12.5
            , 'mock-output-current' => 2.1
            , 'mock-on-state' => 1
            , 'mock-voltage-setpoint' => 12.47
            , 'mock-current-setpoint' => 2.09
            , 'calibration' => { current => [ { requested => 1.5, sampled => 1, actual => 2 }
                                          , { requested => 3, sampled => 2, actual => 5 }
                                          ]
                             }
            };
  $interface = PowerSupplyControl::t::MockInterface->new($config);
  $current = $interface->getOutputCurrent();
  is($current, 5.3, 'getOutputCurrent returns correct current with calibration');

  ($cooked_current, $raw_current) = $interface->getOutputCurrent();
  is($cooked_current, 5.3, 'getOutputCurrent returns correct cooked current with calibration');
  is($raw_current, 2.1, 'getOutputCurrent returns correct raw current with calibration');
};

# Test setVoltage method
subtest 'setVoltage method' => sub {
  my $interface = PowerSupplyControl::t::MockInterface->new;
  
  # Test setting voltage within limits
  note('Default result - true result, but no on-state or current set point result');
  $interface->setResult('voltage');
  $interface->setCurrentLimits(1.1, 9.9);
  $interface->setPowerLimits(1,1000);
  my $result = $interface->setVoltage(15.0);
  is($interface->{'last-setVoltage'}, [ 15.0, 9.9 ], 'correct values sent to _setVoltage');
  is($result, exact_ref($interface), 'setVoltage returns self for chaining');
  is($interface->getVoltageSetPoint(), 15.0, 'setVoltage sets voltage setpoint - no calibration');
  is($interface->isOn, 1, 'setVoltage turns output on');
  my ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 9.9, 'Cooked current set point is now max current - no calibration');
  is($raw, 9.9, 'Raw current set point is now max current - no calibration');

  # Verify that _setVoltage is not called if the requested voltage is the same as the currently set voltage
  delete $interface->{'last-setVoltage'};
  delete $interface->{'last-setCurrent'};
  $interface->setVoltage(15.0);
  is($interface->{'last-setVoltage'}, undef, '_setVoltage is not called if no change in voltage');
  is($interface->{'last-setCurrent'}, undef, '_setCurrent is not called if no change in current');

  $interface->setVoltage(14.99999);
  is($interface->{'last-setVoltage'}, undef, '_setVoltage is not called if change is insignificant');

  $interface->setCurrentLimits(1.1, 8.8);
  $interface->setVoltage(15.0);
  is($interface->{'last-setVoltage'}, undef, '_setVoltage is not called if no change in voltage');
  is($interface->{'last-setCurrent'}, [ 8.8 ], 'correct values set to _setCurrent for altered max current setting');

  # Verify that _setVoltage is called if the requested voltage is different from the current setpoint
  delete $interface->{'last-setVoltage'};
  delete $interface->{'last-setCurrent'};
  $interface->setVoltage(15.1);
  is($interface->{'last-setVoltage'}, [ 15.1, 8.8 ], 'correct values sent to _setVoltage');
  is($interface->{'last-setCurrent'}, undef, '_setCurrent is not called if no change in current');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result and true on-state but no current set point result');
  $interface->setResult('voltage', 1, 1);
  $interface->setCurrentLimits(2.2, 8.8);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setVoltage(14.7);
  is($interface->{'last-setVoltage'}, [ 14.7, 8.8 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 14.7, 'setVoltage sets voltage setpoint - no calibration');
  is($interface->isOn, 1, 'setVoltage turns output on');
  ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 8.8, 'Cooked current set point is now max current - no calibration');
  is($raw, 8.8, 'Raw current set point is now max current - no calibration');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result and true on-state and current set point result');
  $interface->setResult('voltage', 1, 1, 8.9);
  $interface->setCurrentLimits(2.3, 8.7);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setVoltage(14.5);
  is($interface->{'last-setVoltage'}, [ 14.5, 8.7 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 14.5, 'setVoltage sets voltage setpoint - no calibration');
  is($interface->isOn, 1, 'setVoltage turns output on');
  ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 8.9, 'Cooked current set point reflects returned value - no calibration');
  is($raw, 8.9, 'Raw current set point reflects returned value - no calibration');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result true false on-state and current set point result');
  $interface->setResult('voltage', 1, 0, 9.1);
  $interface->setCurrentLimits(2.3, 8.7);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setVoltage(14.2);
  is($interface->getVoltageSetPoint(), 14.2, 'setVoltage sets voltage setpoint - no calibration');
  is($interface->{'last-setVoltage'}, [ 14.2, 8.7 ], 'correct values sent to _setVoltage');
  is($interface->isOn, 1, 'setVoltage turns output on');
  ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 9.1, 'Cooked current set point reflects returned value - no calibration');
  is($raw, 9.1, 'Raw current set point reflects returned value - no calibration');

  note('test voltage, current and power limits');
  $interface->setVoltageLimits(3, 12);
  $interface->setResult('voltage', 1, 1, -1);
  $interface->setVoltage(13);
  is($interface->{'last-setVoltage'}, [ 12, 8.7 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 12, 'setVoltage sets voltage setpoint to maximum - no calibration');
  is($interface->getCurrentSetPoint, 8.7, 'setVoltage sets current setpoint to max current');

  $interface->setVoltage(2.5);
  is($interface->{'last-setVoltage'}, [ 3, 8.7 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 3, 'setVoltage sets voltage setpoint to minimum - no calibration');
  is($interface->getCurrentSetPoint, 8.7, 'setVoltage sets current setpoint to max current');

  $interface->setPowerLimits(1, 90);
  $interface->setVoltage(13);
  is($interface->{'last-setVoltage'}, [ 12, 7.5 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 12, 'setVoltage sets voltage setpoint to maximum - no calibration');
  is($interface->getCurrentSetPoint, 7.5, 'setVoltage sets current setpoint based on max power');

  my $config = { calibration => { voltage => offset_estimator(1,2), current => offset_estimator(0.5, 1.5) }};
  $interface = PowerSupplyControl::t::MockInterface->new($config);

  note('Default calibrated result - true result, but no on-state or current set point result');
  $interface->setResult('voltage');
  $interface->setCurrentLimits(1.1, 9.9);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setVoltage(10.0);
  is($interface->{'last-setVoltage'}, [ 11.0, 9.9 ], 'correct values sent to _setVoltage');
  is($interface->getVoltageSetPoint(), 10.0, 'setVoltage sets voltage setpoint - with calibration');
  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 10.0, 'Cooked voltage set point is now requested voltage - with calibration');
  is($raw, 11.0, 'Raw voltage set point is now requested voltage - with calibration');
  is($interface->isOn, 1, 'setVoltage turns output on');
  ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 9.4, 'Cooked current set point is now max current with calibration offset');
  is($raw, 9.9, 'Raw current set point is now max current with calibration');

};

# Test setCurrent method
subtest 'setCurrent method' => sub {
  my $interface = PowerSupplyControl::t::MockInterface->new;
  
  note('Default result - true result, but no on-state or voltage set point result');
  $interface->setResult('current');
  $interface->setVoltageLimits(2, 30);
  $interface->setPowerLimits(1,1000);
  my $result = $interface->setCurrent(5.0);
  is($interface->{'last-setCurrent'}, [ 5.0, 30 ], 'correct values sent to _setCurrent');
  is($result, exact_ref($interface), 'setCurrent returns self for chaining');
  is($interface->getCurrentSetPoint, 5.0, 'setCurrent sets current setpoint - no calibration');
  is($interface->isOn, 1, 'setCurrent turns output on');
  my ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 30, 'Cooked voltage set point is now max voltage - no calibration');
  is($raw, 30, 'Raw voltage set point is now max voltage - no calibration');

  # Verify that _setCurrent is not called if the requested current is the same as the currently set current
  delete $interface->{'last-setVoltage'};
  delete $interface->{'last-setCurrent'};
  $interface->setCurrent(5.0);
  is($interface->{'last-setCurrent'}, undef, '_setCurrent is not called if no change in current');
  is($interface->{'last-setVoltage'}, undef, '_setVoltage is not called if no change in voltage');

  $interface->setCurrent(4.99999);
  is($interface->{'last-setCurrent'}, undef, '_setCurrent is not called if change is insignificant');

  $interface->setVoltageLimits(2, 29);
  $interface->setCurrent(5.0);
  is($interface->{'last-setCurrent'}, undef, '_setCurrent is not called if no change in current');
  is($interface->{'last-setVoltage'}, [ 29 ], 'correct values set to _setVoltage for altered max voltage setting');

  # Verify that _setCurrent is called if the requested current is different from the current setpoint
  delete $interface->{'last-setVoltage'};
  delete $interface->{'last-setCurrent'};
  $interface->setCurrent(5.1);
  is($interface->{'last-setCurrent'}, [ 5.1, 29 ], 'correct values sent to _setCurrent');
  is($interface->{'last-setVoltage'}, undef, '_setVoltage is not called if no change in voltage');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result and true on-state but no voltage set point result');
  $interface->setResult('current', 1, 1);
  $interface->setVoltageLimits(2, 29);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setCurrent(5.2);
  is($interface->{'last-setCurrent'}, [ 5.2, 29 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 5.2, 'setCurrent sets current setpoint - no calibration');
  is($interface->isOn, 1, 'setCurrent turns output on');
  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 29, 'Cooked voltage set point is now max voltage - no calibration');
  is($raw, 29, 'Raw voltage set point is now max voltage - no calibration');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result and true on-state and voltage set point result');
  $interface->setResult('current', 1, 1, 25);
  $interface->setVoltageLimits(2, 29);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setCurrent(4.5);
  is($interface->{'last-setCurrent'}, [ 4.5, 29 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 4.5, 'setCurrent sets current setpoint - no calibration');
  is($interface->isOn, 1, 'setCurrent turns output on');
  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 25, 'Cooked voltage set point reflects returned value - no calibration');
  is($raw, 25, 'Raw voltage set point reflects returned value - no calibration');

  $interface = PowerSupplyControl::t::MockInterface->new;
  note('true result true false on-state and voltage set point result');
  $interface->setResult('current', 1, 0, 25);
  $interface->setVoltageLimits(2, 29);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setCurrent(4.4);
  is($interface->{'last-setCurrent'}, [ 4.4, 29 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 4.4, 'setCurrent sets current setpoint - no calibration');
  is($interface->isOn, 1, 'setCurrent turns output on');
  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 25, 'Cooked voltage set point reflects returned value - no calibration');
  is($raw, 25, 'Raw voltage set point reflects returned value - no calibration');

  note('test voltage, current and power limits');
  $interface->setCurrentLimits(3, 12);
  $interface->setVoltageLimits(2, 30);
  $interface->setResult('current', 1, 1, -1);
  $interface->setCurrent(13);
  is($interface->{'last-setCurrent'}, [ 12, 30 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 12, 'setCurrent sets current setpoint to maximum - no calibration');
  is($interface->getVoltageSetPoint, 30, 'setCurrent sets voltage setpoint to max voltage');

  $interface->setCurrent(2.5);
  is($interface->{'last-setCurrent'}, [ 3, 30 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 3, 'setCurrent sets current setpoint to minimum - no calibration');
  is($interface->getVoltageSetPoint, 30, 'setCurrent sets voltage setpoint to max voltage');

  $interface->setPowerLimits(1, 90);
  $interface->setCurrent(13);
  is($interface->{'last-setCurrent'}, [ 12, 7.5 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 12, 'setCurrent sets current setpoint to maximum - no calibration');
  is($interface->getVoltageSetPoint, 7.5, 'setCurrent sets voltage setpoint based on max power');

  my $config = { calibration => { voltage => offset_estimator(1,2), current => offset_estimator(0.5, 1.5) }};
  $interface = PowerSupplyControl::t::MockInterface->new($config);

  note('Default calibrated result - true result, but no on-state or voltage set point result');
  $interface->setResult('current');
  $interface->setVoltageLimits(2, 30);
  $interface->setPowerLimits(1,1000);
  $result = $interface->setCurrent(6.0);
  is($interface->{'last-setCurrent'}, [ 6.5, 30 ], 'correct values sent to _setCurrent');
  is($interface->getCurrentSetPoint, 6.0, 'setCurrent sets current setpoint - with calibration');
  ($cooked, $raw) = $interface->getCurrentSetPoint;
  is($cooked, 6.0, 'Cooked current set point is now requested current - with calibration');
  is($raw, 6.5, 'Raw current set point is now requested current - with calibration');
  is($interface->isOn, 1, 'setCurrent turns output on');
  ($cooked, $raw) = $interface->getVoltageSetPoint;
  is($cooked, 29, 'Cooked voltage set point is now max voltage with calibration offset');
  is($raw, 30, 'Raw voltage set point is now max voltage - with calibration');

};

# Test setPower method
subtest 'setPower method' => sub {
  my $config = { 'mock-output-voltage' => 12.0
               , 'mock-output-current' => 4.0
               , 'mock-on-state' => 1
               , 'mock-voltage-setpoint' => 12.01
               , 'mock-current-setpoint' => 8.0
               };
  my $interface = PowerSupplyControl::t::MockInterface->new($config)
                ->setPowerLimits(1, 1000)
                ->setVoltageLimits(2, 30)
                ->setCurrentLimits(0.5, 8.1);

  # Test setting power with calculated resistance
  my $result = $interface->setPower(27);  # currently 12/4 = 3 ohms, so 27W = 9V * 3A
  is($result, exact_ref($interface), '27W/3ohms: setPower returns self for chaining');
  $result = $interface->getVoltageSetPoint;
  is($result, 9, '27W/3ohms: setPower calculates voltage correctly');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.1, '27W/3ohms: setPower sets current setpoint to max current');

  $result = $interface->setPower(27, 4);  # 27W with 4 ohm resistance
  $result = $interface->getVoltageSetPoint;
  is($result, float(10.392, tolerance => 0.001), '27W/4ohms: setPower uses provided resistance correctly');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.1, '27W/4ohms: setPower sets current setpoint to max current');

  note('Power exceeds maximum voltage');
  $interface->setPower(350);
  $result = $interface->getVoltageSetPoint;
  is($result, 30, '350W/3ohms: setPower sets voltage setpoint to max voltage');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.1, '350W/3ohms: setPower sets current setpoint based on max power');

  note('Power exceeds maximum current');
  $interface->setCurrentLimits(0.5, 6.0);
  $result = $interface->setPower(250);
  $result = $interface->getVoltageSetPoint;
  is($result, float(27.386, tolerance => 0.001), '250W/3ohms: setPower sets voltage correctly');
  $result = $interface->getCurrentSetPoint;
  is($result, 6.0, '250W/3ohms: setPower limits current based on requested power');

  note('Power exceeds maximum power');
  $interface->setPowerLimits(3, 100);
  $interface->setPower(250);
  $result = $interface->getVoltageSetPoint;
  is($result, float(17.321, tolerance => 0.001), '250W/3ohms: setPower sets voltage based on power limit');
  $result = $interface->getCurrentSetPoint;
  is($result, float(5.773, tolerance => 0.001), '250W/3ohms: setPower limits current based on power limit');

  $interface->setPower(2);
  $result = $interface->getVoltageSetPoint;
  is($result, float(3, tolerance => 0.001), '2W/3ohms: setPower sets voltage based on power limit');
  $result = $interface->getCurrentSetPoint;
  is($result, 6.0, '2W/3ohms: setPower limits current based on max current');

  note('setPower when output current is currently zero');
  # setPower when output current is currently zero
  $config = { 'mock-output-current' => 0
            , 'mock-output-voltage' => 8.61
            , 'mock-on-state' => 1
            , 'mock-voltage-setpoint' => 8.60
            , 'mock-current-setpoint' => 8.0
            , current => { minimum => 0.5, maximum => 11.0, measurable => 2 }
            , voltage => { minimum => 2, maximum => 30 }
            , power => { minimum => 1, maximum => 1000 }
            , rows => [ { voltage => 8.61, current => 5.74 } ] };
  $interface = PowerSupplyControl::t::MockInterface->new($config);

  # Confirm pre-test state
  is($interface->isOn, T(), 'output is initially on');
  $result = $interface->getOutputVoltage;
  is($result, 8.61, 'output voltage is initially 8.61V');
  $result = $interface->getOutputCurrent;
  is($result, 0, 'output current is initially 0');
  $result = $interface->getVoltageSetPoint;
  is($result, 8.60, 'voltage setpoint is initially 8.60V');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.0, 'current setpoint is initially 8.0A');
  is($interface->{'poll-count'}, 0, 'We have not polled yet');

  like(dies {$interface->setPower(27)}
     , qr/Resistance.*not available/i
     , 'setPower croaks when output is on but current is zero'
     );

  $result = $interface->getOutputVoltage;
  is($interface->isOn, T(), 'output is still on after setPower');
  is($result, 8.61, '27W/1.5ohms: failed setPower call changed nothing');
  $result = $interface->getOutputCurrent;
  is($result, 0, '27W/3ohms: failed setPower call changed nothing');
  $result = $interface->getVoltageSetPoint;
  is($result, 8.60, '27W/1.5ohms: voltage setpoint is unchanged');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.0, '27W/1.5ohms: current setpoint is unchanged');
  is($interface->{'poll-count'}, 0, 'We still have not polled.');

  # setPower when output is currently off
  $config = { 'mock-output-current' => 0
            , 'mock-output-voltage' => 0
            , 'mock-on-state' => 0
            , 'mock-voltage-setpoint' => 8.60
            , 'mock-current-setpoint' => 8.0
            , current => { minimum => 0.5, maximum => 11.0, measurable => 2 }
            , voltage => { minimum => 2, maximum => 30 }
            , power => { minimum => 1, maximum => 1000 }
            , rows => [ { voltage => 8.64, current => 4.80 } ] };
  $interface = PowerSupplyControl::t::MockInterface->new($config);

  # Confirm pre-test state
  is($interface->isOn, F(), 'output is initially off');
  $result = $interface->getOutputVoltage;
  is($result, 0, 'output voltage is initially 0');
  $result = $interface->getOutputCurrent;
  is($result, 0, 'output current is initially 0');
  $result = $interface->getVoltageSetPoint;
  is($result, 8.60, 'voltage setpoint is initially 8.60V');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.0, 'current setpoint is initially 8.0A');
  is($interface->{'poll-count'}, 0, 'We have not polled yet');

  like(dies {$interface->setPower(42) }
     , qr/Resistance.*not available/i
     , 'setPower croaks when output is off and current is zero'
     );

  is($interface->isOn, F(), 'output is still off after setPower');
  $result = $interface->getOutputVoltage;
  is($result, 0, 'output voltage is still 0 after setPower');
  $result = $interface->getOutputCurrent;
  is($result, 0, 'output current is still 0 after setPower');
  $result = $interface->getVoltageSetPoint;
  is($result, 8.60, '42W/3ohms: Output voltage is still 8.60V after setPower');
  $result = $interface->getCurrentSetPoint;
  is($result, 8.0, '42W/3ohms: Output current is still 8.0A after setPower');
  is($interface->{'poll-count'}, 0, 'We still have not polled.');

};

# Test on method
subtest 'on method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test turning output on
    $interface->on(1);
    is($interface->isOn, T(), 'on(1) turns output on');
    is($interface->{'mock-on-state'}, T(), 'on(1) called subclass implementation');
    
    # Test turning output off
    $interface->on(0);
    is($interface->isOn, F(), 'on(0) turns output off');
    is($interface->{'mock-on-state'}, F(), 'on(0) called subclass implementation');

    # Test with truthy values
    $interface->on('true');
    is($interface->isOn, T(), 'on with truthy value turns output on');
    is($interface->{'mock-on-state'}, T(), 'on with truthy value called subclass implementation');

    # Test with falsy values
    $interface->on('');
    is($interface->isOn, F(), 'on with falsy value turns output off');
    is($interface->{'mock-on-state'}, F(), 'on with falsy value called subclass implementation');
};

# Test getMinimumCurrent method
subtest 'getMinimumCurrent method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test with default configuration
    is($interface->getMinimumCurrent(), 0.1, 'getMinimumCurrent returns default minimum');
    
    # Test with custom configuration
    my $custom_config = {
        current => { minimum => 0.5, maximum => 10 }
    };
    my $custom_interface = PowerSupplyControl::t::MockInterface->new($custom_config);
    is($custom_interface->getMinimumCurrent(), 0.5, 'getMinimumCurrent returns configured minimum');
};

# Test getMeasurableCurrent method
subtest 'getMeasurableCurrent method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test with default configuration
    is($interface->getMeasurableCurrent(), 1, 'getMeasurableCurrent returns measurable current');
    
    # Test with custom configuration
    my $custom_config = {
        current => { minimum => 0.1, maximum => 10, measurable => 2 }
    };
    my $custom_interface = PowerSupplyControl::t::MockInterface->new($custom_config);
    is($custom_interface->getMeasurableCurrent(), 2, 'getMeasurableCurrent returns configured measurable current');
    
    # Test when measurable is not set (should fall back to minimum)
    my $fallback_config = {
        current => { minimum => 0.3, maximum => 10 }
    };
    my $fallback_interface = PowerSupplyControl::t::MockInterface->new($fallback_config);
    is($fallback_interface->getMeasurableCurrent(), 0.3, 'getMeasurableCurrent falls back to minimum');
};

# Test getCurrentLimits method
subtest 'getCurrentLimits method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test with default configuration
    my ($min, $max) = $interface->getCurrentLimits();
    is($min, 0.1, 'getCurrentLimits returns default minimum current');
    is($max, 10, 'getCurrentLimits returns default maximum current');
    
    # Test with custom configuration
    my $custom_config = {
        current => { minimum => 0.5, maximum => 15 }
    };
    my $custom_interface = PowerSupplyControl::t::MockInterface->new($custom_config);
    ($min, $max) = $custom_interface->getCurrentLimits();
    is($min, 0.5, 'getCurrentLimits returns configured minimum current');
    is($max, 15, 'getCurrentLimits returns configured maximum current');
};

# Test getVoltageLimits method
subtest 'getVoltageLimits method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test with default configuration
    my ($min, $max) = $interface->getVoltageLimits();
    is($min, 1, 'getVoltageLimits returns default minimum voltage');
    is($max, 30, 'getVoltageLimits returns default maximum voltage');
    
    # Test with custom configuration
    my $custom_config = {
        voltage => { minimum => 2, maximum => 50 }
    };
    my $custom_interface = PowerSupplyControl::t::MockInterface->new($custom_config);
    ($min, $max) = $custom_interface->getVoltageLimits();
    is($min, 2, 'getVoltageLimits returns configured minimum voltage');
    is($max, 50, 'getVoltageLimits returns configured maximum voltage');
};

# Test getPowerLimits method
subtest 'getPowerLimits method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Test with default configuration
    my ($min, $max) = $interface->getPowerLimits();
    is($min, 10, 'getPowerLimits returns default minimum power');
    is($max, 120, 'getPowerLimits returns default maximum power');
    
    # Test with custom configuration
    my $custom_config = {
        power => { minimum => 1, maximum => 200 }
    };
    my $custom_interface = PowerSupplyControl::t::MockInterface->new($custom_config);
    ($min, $max) = $custom_interface->getPowerLimits();
    is($min, 1, 'getPowerLimits returns configured minimum power');
    is($max, 200, 'getPowerLimits returns configured maximum power');
};

# Test resetCalibration method
subtest 'resetCalibration method' => sub {
    my $config = { calibration => { voltage => offset_estimator(1,2), current => offset_estimator(0.5, 1.5) }};
    my $interface = PowerSupplyControl::t::MockInterface->new($config);
    
    is($interface->{'voltage-requested'}, D(), 'voltage-requested calibration set');
    is($interface->{'current-requested'}, D(), 'current-requested calibration set');
    is($interface->{'voltage-output'}, D(), 'voltage-output calibration set');
    is($interface->{'current-output'}, D(), 'current-output calibration set');
    is($interface->{'voltage-setpoint'}, D(), 'voltage-setpoint calibration set');
    is($interface->{'current-setpoint'}, D(), 'current-setpoint calibration set');

    $interface->resetCalibration();
    
    is($interface->{'voltage-requested'}, U(), 'voltage-requested calibration removed');
    is($interface->{'current-requested'}, U(), 'current-requested calibration removed');
    is($interface->{'voltage-output'}, U(), 'voltage-output calibration removed');
    is($interface->{'current-output'}, U(), 'current-output calibration removed');
    is($interface->{'voltage-setpoint'}, U(), 'voltage-setpoint calibration removed');
    is($interface->{'current-setpoint'}, U(), 'current-setpoint calibration removed');
};

# Note: shutdown method doesn't exist in the base Interface class

# Test DESTROY method
subtest 'DESTROY method' => sub {
    my $interface = PowerSupplyControl::t::MockInterface->new();
    
    # Turn output on first
    $interface->on(1);
    is($interface->isOn, 1, 'output is on before destruction');
    
    # Simulate destruction by calling DESTROY directly
    $interface->DESTROY();
    
    # Verify output was turned off
    is($interface->isOn, 0, 'DESTROY turns output off');
};

done_testing; 