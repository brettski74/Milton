#!/usr/bin/perl

use lib '.';
use strict;
use warnings;
use Test2::V0;
use PowerSupplyControl::t::MockEventLoop;

subtest 'timerEvent linking' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    my $s1 = $ev->poll('timerEvent');
    is($s1->{event}, 'timerEvent', 'event is timerEvent');
    is($s1->{period}, 1, 'period is set');
    ok(!exists $s1->{last}, 'first timerEvent has no last');
    ok(!exists $s1->{next}, 'first timerEvent has no next');

    my $s2 = $ev->poll('timerEvent');
    ref_is($s2->{last}, $s1, 'second timerEvent last points to first');
    ref_is($s1->{next}, $s2, 'first timerEvent next points to second');
    ok(!exists $s2->{next}, 'second timerEvent has no next yet');

    my $s3 = $ev->poll('timerEvent');
    ref_is($s3->{last}, $s2, 'third timerEvent last points to second');
    ref_is($s2->{next}, $s3, 'second timerEvent next points to third');
    ok(!exists $s3->{next}, 'third timerEvent has no next yet');
};

subtest 'keyEvent linking' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    my $t1 = $ev->poll('timerEvent');
    my $k1 = $ev->poll('keyEvent');
    ref_is($k1->{last}, $t1, 'keyEvent last points to previous timerEvent');
    ok(!exists $k1->{next}, 'keyEvent has no next');

    my $t2 = $ev->poll('timerEvent');
    ref_is($t2->{last}, $t1, 'timerEvent after keyEvent last points to previous timerEvent');
    ref_is($t1->{next}, $t2, 'previous timerEvent next points to this timerEvent');
    ok(!exists $t2->{next}, 'new timerEvent has no next yet');

    my $k2 = $ev->poll('keyEvent');
    ref_is($k2->{last}, $t2, 'second keyEvent last points to previous timerEvent');
    ok(!exists $k2->{next}, 'second keyEvent has no next');
};

subtest 'mixed event sequence' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    
    # Sequence: timer -> key -> timer -> key -> timer
    my $t1 = $ev->poll('timerEvent');
    my $k1 = $ev->poll('keyEvent');
    my $t2 = $ev->poll('timerEvent');
    my $k2 = $ev->poll('keyEvent');
    my $t3 = $ev->poll('timerEvent');

    # Verify that the event loop object is available in the status object
    ref_is($t1->{'event-loop'}, $ev, 't1->event-loop === ev');
    ref_is($t2->{'event-loop'}, $ev, 't2->event-loop === ev');
    ref_is($t3->{'event-loop'}, $ev, 't3->event-loop === ev');
    ref_is($k1->{'event-loop'}, $ev, 'k1->event-loop === ev');
    ref_is($k2->{'event-loop'}, $ev, 'k2->event-loop === ev');

    # Verify timer chain
    ref_is($t1->{next}, $t2, 't1->next = t2');
    ref_is($t2->{next}, $t3, 't2->next = t3');
    ok(!exists $t3->{next}, 't3 has no next');
    
    # Verify last links
    ref_is($t2->{last}, $t1, 't2->last = t1');
    ref_is($t3->{last}, $t2, 't3->last = t2');
    ref_is($k1->{last}, $t1, 'k1->last = t1');
    ref_is($k2->{last}, $t2, 'k2->last = t2');
    
    # Verify key events don't have next links
    ok(!exists $k1->{next}, 'k1 has no next');
    ok(!exists $k2->{next}, 'k2 has no next');
};

subtest 'status enrichment' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    my $status = $ev->poll('timerEvent', 'custom_key', 'custom_value');
    
    is($status->{event}, 'timerEvent', 'event is set');
    is($status->{period}, 1, 'period is set');
    is($status->{custom_key}, 'custom_value', 'custom attributes are set');
    is($status->{voltage}, 12.5, 'interface data is included');
    is($status->{resistance}, float(5.952380952, tolerance => 0.00001), 'controller resistance is included');
    is($status->{temperature}, float(495.2380952, tolerance => 0.00001), 'controller temperature is included');
};

subtest 'custom mock data' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    
    # Set custom mock data
    my $custom_data = [
        ['timestamp', 'voltage', 'current', 'power'],
        ['2024-01-01 10:00:00', 10.0, 1.5, 15.0],
        ['2024-01-01 10:01:00', 11.0, 1.6, 17.6],
        ['2024-01-01 10:02:00', 12.0, 1.7, 20.4]
    ];
    $ev->{interface}->setMockData($custom_data);
    
    # Test first row
    my $s1 = $ev->poll('timerEvent');
    is($s1->{timestamp}, '2024-01-01 10:00:00', 'first row timestamp');
    is($s1->{voltage}, 10.0, 'first row voltage');
    is($s1->{current}, 1.5, 'first row current');
    is($s1->{power}, 15.0, 'first row power');
    
    # Test second row
    my $s2 = $ev->poll('timerEvent');
    is($s2->{timestamp}, '2024-01-01 10:01:00', 'second row timestamp');
    is($s2->{voltage}, 11.0, 'second row voltage');
    is($s2->{current}, 1.6, 'second row current');
    is($s2->{power}, 17.6, 'second row power');
    
    # Test third row
    my $s3 = $ev->poll('timerEvent');
    is($s3->{timestamp}, '2024-01-01 10:02:00', 'third row timestamp');
    is($s3->{voltage}, 12.0, 'third row voltage');
    is($s3->{current}, 1.7, 'third row current');
    is($s3->{power}, 20.4, 'third row power');
    
    # Test wrapping around to first row
    my $s4 = $ev->poll('timerEvent');
    is($s4->{timestamp}, '2024-01-01 10:00:00', 'wrapped around to first row');
    is($s4->{voltage}, 10.0, 'wrapped voltage');
    
    # Verify linking still works
    ref_is($s2->{last}, $s1, 's2->last = s1');
    ref_is($s1->{next}, $s2, 's1->next = s2');
    ref_is($s3->{last}, $s2, 's3->last = s2');
    ref_is($s2->{next}, $s3, 's2->next = s3');
    ref_is($s4->{last}, $s3, 's4->last = s3');
    ref_is($s3->{next}, $s4, 's3->next = s4');
};

subtest 'default mock data' => sub {
    my $ev = PowerSupplyControl::t::MockEventLoop->new();
    
    # Test default data
    my $s1 = $ev->poll('timerEvent');
    is($s1->{id}, 1, 'default id');
    is($s1->{voltage}, 12.5, 'default voltage');
    is($s1->{current}, 2.1, 'default current');
    is($s1->{power}, 26.25, 'default power');
    is($s1->{temperature}, float(495.2380952, tolerance => 0.00001), 'default temperature');
    
    # Test wrapping around (only one row in default data)
    my $s2 = $ev->poll('timerEvent');
    is($s2->{id}, 1, 'wrapped around to same data');
    is($s2->{voltage}, 12.5, 'wrapped voltage');
    
    # Verify linking works
    ref_is($s2->{last}, $s1, 's2->last = s1');
    ref_is($s1->{next}, $s2, 's1->next = s2');
};

done_testing; 