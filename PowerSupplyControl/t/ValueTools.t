#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use Test2::V0;
use PowerSupplyControl::ValueTools qw(boolify checkMinimum checkMaximum checkMinMax timestamp hexToNumber);

# Test boolify function
subtest 'boolify function' => sub {
    # Test basic boolean conversion
    my @vals = (0, 1, undef, 'false', 'False', 'FALSE', 'true', 'True', 'TRUE');
    boolify(@vals);
    
    is($vals[0], F(), '0 is false');
    is($vals[1], T(), '1 is true');
    is($vals[2], F(), 'undef is false');
    is($vals[3], F(), 'false is false');
    is($vals[4], F(), 'False is false');
    is($vals[5], F(), 'FALSE is false');
    is($vals[6], T(), 'true is true');
    is($vals[7], T(), 'True is true');
    is($vals[8], T(), 'TRUE is true');
    
    # Test other values that should remain unchanged
    my @other_vals = ('hello', 42, -1, '', '0', '1');
    my @original = @other_vals;
    boolify(@other_vals);
    
    is($other_vals[0], 'hello', "'hello' remains unchanged");
    is($other_vals[1], 42, '42 remains unchanged');
    is($other_vals[2], -1, '-1 remains unchanged');
    is($other_vals[3], '', "empty string remains unchanged");
    is($other_vals[4], '0', "'0' string remains unchanged");
    is($other_vals[5], '1', "'1' string remains unchanged");
    
    # Test with some hash values
    my $hash = { 'a' => 'TRUE', 'b' => 'True', 'c' => 'true', 'd' => 'FALSE', 'e' => 'False', 'f' => 'false' };
    boolify($hash->{a}, $hash->{b}, $hash->{c}, $hash->{d}, $hash->{e}, $hash->{f});
    
    is($hash->{a}, T(), 'TRUE is true in a hash');
    is($hash->{b}, T(), 'True is true in a hash');
    is($hash->{c}, T(), 'true is true in a hash');
    is($hash->{d}, F(), 'FALSE is false in a hash');
    is($hash->{e}, F(), 'False is false in a hash');
    is($hash->{f}, F(), 'false is false in a hash');
};

# Test hexToNumber function
subtest 'hexToNumber function' => sub {
    # Test basic hex conversion
    my @hex_vals = ('0', '1', 'A', 'a', 'F', 'f', '10', 'FF', 'ff', '100', 'FFFF');
    my @original = @hex_vals;
    hexToNumber(@hex_vals);
    
    is($hex_vals[0], 0, "'0' converts to 0");
    is($hex_vals[1], 1, "'1' converts to 1");
    is($hex_vals[2], 10, "'A' converts to 10");
    is($hex_vals[3], 10, "'a' converts to 10");
    is($hex_vals[4], 15, "'F' converts to 15");
    is($hex_vals[5], 15, "'f' converts to 15");
    is($hex_vals[6], 16, "'10' converts to 16");
    is($hex_vals[7], 255, "'FF' converts to 255");
    is($hex_vals[8], 255, "'ff' converts to 255");
    is($hex_vals[9], 256, "'100' converts to 256");
    is($hex_vals[10], 65535, "'FFFF' converts to 65535");
    
    # Test edge cases
    my @edge_cases = ('0x0', '0X1', '0xABCD', '0Xabcd');
    hexToNumber(@edge_cases);
    
    is($edge_cases[0], 0, "'0x0' converts to 0");
    is($edge_cases[1], 1, "'0X1' converts to 1");
    is($edge_cases[2], 43981, "'0xABCD' converts to 43981");
    is($edge_cases[3], 43981, "'0Xabcd' converts to 43981");
    
    # Test large numbers
    my @large_nums = ('FFFFFFFF', '7FFFFFFF', '80000000');
    hexToNumber(@large_nums);
    
    is($large_nums[0], 4294967295, "'FFFFFFFF' converts to 4294967295");
    is($large_nums[1], 2147483647, "'7FFFFFFF' converts to 2147483647");
    is($large_nums[2], 2147483648, "'80000000' converts to 2147483648");
    
    # Test single value
    my $single_val = 'DEADBEEF';
    hexToNumber($single_val);
    is($single_val, 3735928559, "'DEADBEEF' converts to 3735928559");
    
    # Test empty array
    my @empty = ();
    hexToNumber(@empty);
    is(scalar @empty, 0, 'Empty array remains empty');
    
    # Test with hash values
    my $hash = { 'a' => '1A', 'b' => '2B', 'c' => '3C' };
    hexToNumber($hash->{a}, $hash->{b}, $hash->{c});
    
    is($hash->{a}, 26, "'1A' converts to 26 in hash");
    is($hash->{b}, 43, "'2B' converts to 43 in hash");
    is($hash->{c}, 60, "'3C' converts to 60 in hash");
    
    # Test mixed case
    my @mixed_case = ('aBcD', 'EfGh', '1234');
    hexToNumber(@mixed_case);
    
    is($mixed_case[0], 43981, "'aBcD' converts to 43981");
    is($mixed_case[1], 239, "'EfGh' converts to 239 (invalid 'G' ignored)");
    is($mixed_case[2], 4660, "'1234' converts to 4660");
};

# Test checkMinimum function
subtest 'checkMinimum function' => sub {
    # Test values that are already at or above minimum
    my $val1 = 10;
    is(checkMinimum($val1, 5), T(), 'checkMinimum returns true when value >= min');
    is($val1, 10, 'value unchanged when already >= min');
    
    my $val2 = 5;
    is(checkMinimum($val2, 5), T(), 'checkMinimum returns true when value == min');
    is($val2, 5, 'value unchanged when value == min');
    
    # Test values that are below minimum
    my $val3 = 3;
    is(checkMinimum($val3, 5), F(), 'checkMinimum returns false when value < min');
    is($val3, 5, 'value set to minimum when value < min');
    
    my $val4 = -10;
    is(checkMinimum($val4, 0), F(), 'checkMinimum returns false for negative value');
    is($val4, 0, 'negative value set to minimum');
    
    # Test inside a hash
    my $hash = { 'a' => 3, 'b' => -10, 'c' => 5 };
    is(checkMinimum($hash->{a}, 5), F(), 'checkMinimum returns false when value < min in hash');
    is($hash->{a}, 5, 'value set to minimum when value < min in hash');
    
    is(checkMinimum($hash->{b}, 0), F(), 'checkMinimum returns false for negative value in hash');
    is($hash->{b}, 0, 'negative value set to minimum in hash');

    is(checkMinimum($hash->{c}, 5), T(), 'checkMinimum returns true when value >= min in hash');
    is($hash->{c}, 5, 'value unchanged when value >= min in hash');

    is(checkMinimum($hash->{d}, 5, $hash->{c}, 4), F(), 'checkMinimum returns false when first value is below minimum');
    is ($hash->{d}, 5, 'value set to minimum when first value is undefined');
    is(checkMinimum($hash->{d}, 5, $hash->{f}, -4), F(), 'checkMinimum returns false when second value is below minimum');
    is ($hash->{f}, -4, 'value set to minimum when second value is undefined - negative value');

};

# Test checkMaximum function
subtest 'checkMaximum function' => sub {
    # Test values that are already at or below maximum
    my $val1 = 5;
    is(checkMaximum($val1, 10), T(), 'checkMaximum returns true when value <= max');
    is($val1, 5, 'value unchanged when already <= max');
    
    my $val2 = 10;
    is(checkMaximum($val2, 10), T(), 'checkMaximum returns true when value == max');
    is($val2, 10, 'value unchanged when value == max');
    
    # Test values that are above maximum
    my $val3 = 15;
    is(checkMaximum($val3, 10), F(), 'checkMaximum returns false when value > max');
    is($val3, 10, 'value set to maximum when value > max');
    
    my $val4 = -10;
    is(checkMaximum($val4, -12), F(), 'checkMaximum returns false for negative value');
    is($val4, -12, 'negative value set to maximum');
    
    # Test inside a hash
    my $hash = { 'a' => 15, 'b' => -10, 'c' => 10 };
    is(checkMaximum($hash->{a}, 9), F(), 'checkMaximum returns false when value > max in hash');
    is($hash->{a}, 9, 'value set to maximum when value > max in hash');
    
    is(checkMaximum($hash->{b}, -15), F(), 'checkMaximum returns false for negative value in hash');
    is($hash->{b}, -15, 'negative value set to maximum in hash');

    is(checkMaximum($hash->{c}, 10), T(), 'checkMaximum returns true when value <= max in hash');
    is($hash->{c}, 10, 'value unchanged when value <= max in hash');

    is(checkMaximum($hash->{d}, 9, $hash->{c}, 10), F(), 'checkMaximum returns false when first value is undefined');
    is ($hash->{d}, 9, 'value set to maximum when first value is undefined');
    is(checkMaximum($hash->{d}, 9, $hash->{f}, -3), F(), 'checkMaximum returns false when second value is undefined');
    is ($hash->{f}, -3, 'value set to maximum when second value is undefined - negative value');
};

# Test checkMinMax function
subtest 'checkMinMax function' => sub {
    # Test values within range
    my $val1 = 5;
    is(checkMinMax($val1, 0, 10), T(), 'checkMinMax returns true when value within range');
    is($val1, 5, 'value unchanged when within range');
    
    my $val2 = 0;
    is(checkMinMax($val2, 0, 10), T(), 'checkMinMax returns true when value at minimum');
    is($val2, 0, 'value unchanged when at minimum');
    
    my $val3 = 10;
    is(checkMinMax($val3, 0, 10), T(), 'checkMinMax returns true when value at maximum');
    is($val3, 10, 'value unchanged when at maximum');
    
    # Test values below minimum
    my $val4 = -5;
    is(checkMinMax($val4, 0, 10), F(), 'checkMinMax returns false when value < min');
    is($val4, 0, 'value set to minimum when below range');
    
    # Test values above maximum
    my $val5 = 15;
    is(checkMinMax($val5, 0, 10), F(), 'checkMinMax returns false when value > max');
    is($val5, 10, 'value set to maximum when above range');
    
    # Test edge cases
    my $val6 = 5;
    is(checkMinMax($val6, 5, 5), T(), 'checkMinMax works when min == max');
    is($val6, 5, 'value unchanged when min == max and value matches');
    
    my $val7 = 3;
    is(checkMinMax($val7, 5, 5), F(), 'checkMinMax returns false when value < min==max');
    is($val7, 5, 'value set to min when min == max and value < min');
    
    my $val8 = 7;
    is(checkMinMax($val8, 5, 5), F(), 'checkMinMax returns false when value > min==max');
    is($val8, 5, 'value set to min when min == max and value > max');
    
    # Test error condition
    ok(dies { checkMinMax(5, 10, 5) }, 'checkMinMax croaks when max < min');

    # Test inside a hash
    my $hash = { 'a' => 5, 'b' => -10, 'c' => 10 };
    is(checkMinMax($hash->{a}, 1, 9), T(), 'checkMinMax returns true when value within range in hash');
    is($hash->{a}, 5, 'value unchanged when within range in hash');
    
    is(checkMinMax($hash->{b}, -1, 7), F(), 'checkMinMax returns false when value < min in hash');
    is($hash->{b}, -1, 'value set to minimum when value < min in hash');

    is(checkMinMax($hash->{c}, 1, 9), F(), 'checkMinMax returns false when value > max in hash');
    is($hash->{c}, 9, 'value set to maximum when value > max in hash');

};

# Test timestamp function
subtest 'timestamp function' => sub {
    # Test current time (approximate)
    my $now = timestamp();
    like($now, qr/^\d{8}-\d{6}$/, 'timestamp returns correct format for current time');

    ok($now gt '20200101-000000', 'timestamp returns a date after 2020');
    
    # Will anybody still be using this in 2500?
    ok($now lt '24991231-235959', 'timestamp returns a date before 2500');

};

done_testing; 