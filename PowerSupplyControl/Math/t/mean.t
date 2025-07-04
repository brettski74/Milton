#!/usr/bin/perl

use lib '.';
use Test2::V0;
use PowerSupplyControl::Math::Util;

my $EPS = 0.00000001;

# Test basic functionality with single key-value pair
subtest 'basic single key-value' => sub {
    my @data = (
        { temperature => 25.5 },
        { temperature => 26.0 },
        { temperature => 24.5 },
        { temperature => 27.0 }
    );
    
    my $mean_temp;
    PowerSupplyControl::Math::Util::mean(\@data, 'temperature', $mean_temp);
    
    # Expected: (25.5 + 26.0 + 24.5 + 27.0) / 4 = 25.75
    is($mean_temp, 25.75, 'single key-value mean calculation');
};

# Test with multiple key-value pairs
subtest 'multiple key-value pairs' => sub {
    my @data = (
        { temperature => 25.5, pressure => 101.3, humidity => 60.0 },
        { temperature => 26.0, pressure => 101.5, humidity => 58.0 },
        { temperature => 24.5, pressure => 101.1, humidity => 62.0 },
        { temperature => 27.0, pressure => 101.7, humidity => 55.0 }
    );
    
    my ($mean_temp, $mean_pressure, $mean_humidity);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure,
        'humidity', $mean_humidity
    );
    
    # Expected means:
    # temperature: (25.5 + 26.0 + 24.5 + 27.0) / 4 = 25.75
    # pressure: (101.3 + 101.5 + 101.1 + 101.7) / 4 = 101.4
    # humidity: (60.0 + 58.0 + 62.0 + 55.0) / 4 = 58.75
    is($mean_temp, 25.75, 'temperature mean');
    is($mean_pressure, 101.4, 'pressure mean');
    is($mean_humidity, 58.75, 'humidity mean');
};

# Test with missing values (undefined keys)
subtest 'missing values handling' => sub {
    my @data = (
        { temperature => 25.5, pressure => 101.3 },
        { temperature => 26.0 },  # missing pressure
        { pressure => 101.1 },    # missing temperature
        { temperature => 27.0, pressure => 101.7 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Expected means (only counting defined values):
    # temperature: (25.5 + 26.0 + 27.0) / 3 = 26.166666...
    # pressure: (101.3 + 101.1 + 101.7) / 3 = 101.366666...
    is($mean_temp, float(26.1666666666667, tolerance => $EPS), 'temperature mean with missing values');
    is($mean_pressure, float(101.3666666666667, tolerance => $EPS), 'pressure mean with missing values');
};

# Test with all missing values for a key
subtest 'all missing values for key' => sub {
    my @data = (
        { temperature => 25.5 },
        { temperature => 26.0 },
        { temperature => 24.5 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # temperature: (25.5 + 26.0 + 24.5) / 3 = 25.333333...
    # pressure: no defined values, should be 0 (initialized value)
    is($mean_temp, float(25.3333333333333, tolerance => $EPS), 'temperature mean');
    is($mean_pressure, undef, 'pressure mean with no defined values');
};

# Test with empty data array
subtest 'empty data array' => sub {
    my @data = ();
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Both should be 0 (initialized values)
    is($mean_temp, undef, 'temperature mean with empty data');
    is($mean_pressure, undef, 'pressure mean with empty data');
};

# Test with single data point
subtest 'single data point' => sub {
    my @data = (
        { temperature => 25.5, pressure => 101.3 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Should be the same as the single value
    is($mean_temp, 25.5, 'temperature mean with single data point');
    is($mean_pressure, 101.3, 'pressure mean with single data point');
};

# Test with zero values
subtest 'zero values' => sub {
    my @data = (
        { temperature => 0, pressure => 0 },
        { temperature => 0, pressure => 0 },
        { temperature => 0, pressure => 0 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Should be 0
    is($mean_temp, 0, 'temperature mean with zero values');
    is($mean_pressure, 0, 'pressure mean with zero values');
};

# Test with negative values
subtest 'negative values' => sub {
    my @data = (
        { temperature => -10.5, pressure => -5.2 },
        { temperature => -15.0, pressure => -3.8 },
        { temperature => -8.5, pressure => -7.1 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Expected means:
    # temperature: (-10.5 + -15.0 + -8.5) / 3 = -11.333333...
    # pressure: (-5.2 + -3.8 + -7.1) / 3 = -5.366666...
    is($mean_temp, float(-11.3333333333333, tolerance => $EPS), 'temperature mean with negative values');
    is($mean_pressure, float(-5.3666666666667, tolerance => $EPS), 'pressure mean with negative values');
};

# Test with mixed positive and negative values
subtest 'mixed positive and negative values' => sub {
    my @data = (
        { temperature => 10.5, pressure => -5.2 },
        { temperature => -15.0, pressure => 3.8 },
        { temperature => 8.5, pressure => -7.1 }
    );
    
    my ($mean_temp, $mean_pressure);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure
    );
    
    # Expected means:
    # temperature: (10.5 + -15.0 + 8.5) / 3 = 1.333333...
    # pressure: (-5.2 + 3.8 + -7.1) / 3 = -2.833333...
    is($mean_temp, float(1.3333333333333, tolerance => $EPS), 'temperature mean with mixed values');
    is($mean_pressure, float(-2.8333333333333, tolerance => $EPS), 'pressure mean with mixed values');
};

# Test with odd number of key-value pairs
subtest 'odd number of key-value pairs' => sub {
    my @data = (
        { temperature => 25.0 },
        { temperature => 26.0 },
        { temperature => 27.0 }
    );
    
    my ($mean_temp, $mean_pressure, $mean_humidity, $mean_wind);
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $mean_temp,
        'pressure', $mean_pressure,
        'humidity', $mean_humidity,
        'wind', $mean_wind
    );
    
    # temperature: (25.0 + 26.0 + 27.0) / 3 = 26.0
    # others: 0 (no defined values)
    is($mean_temp, 26.0, 'temperature mean with odd number of pairs');
    is($mean_pressure, undef, 'pressure mean with odd number of pairs');
    is($mean_humidity, undef, 'humidity mean with odd number of pairs');
    is($mean_wind, undef, 'wind mean with odd number of pairs');
};

# Test that the function modifies the variables passed by reference
subtest 'modifies variables by reference' => sub {
    my @data = (
        { temperature => 25.0, pressure => 101.0 },
        { temperature => 26.0, pressure => 102.0 }
    );
    
    my $original_temp = 999.0;
    my $original_pressure = 888.0;
    
    PowerSupplyControl::Math::Util::mean(\@data, 
        'temperature', $original_temp,
        'pressure', $original_pressure
    );
    
    # Variables should be modified to the calculated means
    is($original_temp, 25.5, 'temperature variable modified');
    is($original_pressure, 101.5, 'pressure variable modified');
};

done_testing(); 