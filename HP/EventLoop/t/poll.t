#!/usr/bin/perl

use lib '.';
use strict;
use warnings;
use Test2::V0;
use HP::t::MockEventLoop;

subtest 'timerEvent linking' => sub {
    my $ev = HP::t::MockEventLoop->new();
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
    my $ev = HP::t::MockEventLoop->new();
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
    my $ev = HP::t::MockEventLoop->new();
    
    # Sequence: timer -> key -> timer -> key -> timer
    my $t1 = $ev->poll('timerEvent');
    my $k1 = $ev->poll('keyEvent');
    my $t2 = $ev->poll('timerEvent');
    my $k2 = $ev->poll('keyEvent');
    my $t3 = $ev->poll('timerEvent');
    
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
    my $ev = HP::t::MockEventLoop->new();
    my $status = $ev->poll('timerEvent', 'custom_key', 'custom_value');
    
    is($status->{event}, 'timerEvent', 'event is set');
    is($status->{period}, 1, 'period is set');
    is($status->{custom_key}, 'custom_value', 'custom attributes are set');
    is($status->{voltage}, 12.5, 'interface data is included');
    is($status->{controller_temp}, 85.2, 'controller data is included');
};

done_testing; 