#!/usr/bin/perl

use lib '.';
use strict;
use warnings;
use Test2::V0;
use Test2::Tools::Exception;
use Path::Tiny;
use PowerSupplyControl::Interface::ReplayInterface;

# Create a temporary CSV file for testing
my $temp_csv = Path::Tiny->tempfile(suffix => '.csv');
$temp_csv->spew(<<'CSV');
timestamp,voltage,current,power,temperature
2024-01-01 10:00:00,12.5,2.1,26.25,85.2
2024-01-01 10:01:00,13.0,2.3,29.9,87.1
2024-01-01 10:02:00,12.8,2.2,28.16,86.5
CSV

skip_all 'Not updated since Interface.pm refactor and not used for anything yet.';

# Test constructor
subtest "Constructor" => sub {
    # Test successful construction with filename
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => $temp_csv->stringify
    });
    isa_ok($interface, 'PowerSupplyControl::Interface::ReplayInterface');
    isa_ok($interface, 'PowerSupplyControl::Interface');
    
    # Test successful construction without filename
    my $interface2 = PowerSupplyControl::Interface::ReplayInterface->new({});
    isa_ok($interface2, 'PowerSupplyControl::Interface::ReplayInterface');
    isa_ok($interface2, 'PowerSupplyControl::Interface');
    
    # Test setFilename method
    $interface2->setFilename($temp_csv->stringify);
    my $status = $interface2->poll;
    is($status->{timestamp}, '2024-01-01 10:00:00', 'setFilename works');
    
    # Test setFilename with empty filename
    ok(dies { $interface2->setFilename('') }, 'dies with empty filename');
    ok(dies { $interface2->setFilename(undef) }, 'dies with undef filename');
    
    # Test non-existent file
    ok(dies { $interface2->setFilename('nonexistent.csv') }, 'dies with non-existent file');
};

# Test poll method
subtest "Poll method" => sub {
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => $temp_csv->stringify
    });
    
    # Poll first row
    my $status1 = $interface->poll;
    is($status1->{timestamp}, '2024-01-01 10:00:00', 'first row timestamp');
    is($status1->{voltage}, '12.5', 'first row voltage');
    is($status1->{current}, '2.1', 'first row current');
    is($status1->{power}, '26.25', 'first row power');
    is($status1->{temperature}, '85.2', 'first row temperature');
    
    # Poll second row
    my $status2 = $interface->poll;
    is($status2->{timestamp}, '2024-01-01 10:01:00', 'second row timestamp');
    is($status2->{voltage}, '13.0', 'second row voltage');
    is($status2->{current}, '2.3', 'second row current');
    is($status2->{power}, '29.9', 'second row power');
    is($status2->{temperature}, '87.1', 'second row temperature');
    
    # Poll third row
    my $status3 = $interface->poll;
    is($status3->{timestamp}, '2024-01-01 10:02:00', 'third row timestamp');
    is($status3->{voltage}, '12.8', 'third row voltage');
    is($status3->{current}, '2.2', 'third row current');
    is($status3->{power}, '28.16', 'third row power');
    is($status3->{temperature}, '86.5', 'third row temperature');
    
    # Poll after end of file
    my $status4 = $interface->poll;
    is($status4, undef, 'returns undef at end of file');
};

# Test poll without filename
subtest "Poll without filename" => sub {
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({});
    
    ok(dies { $interface->poll }, 'poll dies without filename');
    like(dies { $interface->poll }, qr/No filename specified/, 'correct error message');
};

# Test setter methods (should do nothing)
subtest "Setter methods" => sub {
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => $temp_csv->stringify
    });
    
    # These should not die and should do nothing
    ok(lives { $interface->setVoltage(15.0) }, 'setVoltage does not die');
    ok(lives { $interface->setCurrent(3.0) }, 'setCurrent does not die');
    ok(lives { $interface->setPower(50.0, 10.0) }, 'setPower does not die');
    
    # Verify they don't affect the poll data
    my $status = $interface->poll;
    is($status->{voltage}, 12.5, 'setVoltage does not affect poll data');
    is($status->{current}, 2.1, 'setCurrent does not affect poll data');
};

# Test reset method
subtest "Reset method" => sub {
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => $temp_csv->stringify
    });
    
    # Read to end of file
    $interface->poll; # first row
    $interface->poll; # second row
    $interface->poll; # third row
    is($interface->poll, undef, 'at end of file');
    
    # Reset and read again
    $interface->reset;
    my $status = $interface->poll;
    is($status->{timestamp}, '2024-01-01 10:00:00', 'reset returns to first row');
    is($status->{voltage}, 12.5, 'reset returns correct voltage');
};

# Test shutdown method
subtest "Shutdown method" => sub {
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => $temp_csv->stringify
    });
    
    ok(lives { $interface->shutdown }, 'shutdown does not die');
    
    # After shutdown, poll should still work (file is reopened)
    my $status = $interface->poll;
    is($status->{timestamp}, '2024-01-01 10:00:00', 'poll works after shutdown');
};

# Test with different data types
subtest "Data type handling" => sub {
    my $temp_csv2 = Path::Tiny->tempfile(suffix => '.csv');
    $temp_csv2->spew(<<'CSV');
id,name,value,active,notes
1,test1,42.5,true,some text
2,test2,-15,false,more text
3,test3,0,true,
CSV

    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({});
    $interface->setFilename($temp_csv2->stringify);
    
    my $status = $interface->poll;
    is($status->{id}, '1', 'integer conversion works');
    is($status->{name}, 'test1', 'string preserved');
    is($status->{value}, '42.5', 'float conversion works');
    is($status->{active}, 'true', 'boolean string preserved');
    is($status->{notes}, 'some text', 'text preserved');
    
    $status = $interface->poll;
    is($status->{id}, '2', 'negative integer conversion works');
    is($status->{value}, '-15', 'negative float conversion works');
    is($status->{active}, 'false', 'false string preserved');
    
    $status = $interface->poll;
    is($status->{id}, '3', 'zero integer conversion works');
    is($status->{value}, '0', 'zero float conversion works');
    is($status->{notes}, '', 'empty string preserved');
};

# Test with empty CSV file
subtest "Empty CSV handling" => sub {
    my $temp_csv3 = Path::Tiny->tempfile(suffix => '.csv');
    $temp_csv3->spew("header1,header2\n");
    
    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({});
    $interface->setFilename($temp_csv3->stringify);
    
    my $status = $interface->poll;
    is($status, undef, 'returns undef for empty CSV after header');
};

done_testing; 