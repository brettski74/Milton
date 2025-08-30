#!/usr/bin/perl

use lib '.';
use strict;
use Test2::V0;
use Milton::t::MockEventLoop;
use Milton::t::MockCondVar;

use warnings qw(all -uninitialized -redefine);

subtest '_keyWatcher' => sub {
  my $loop = Milton::t::MockEventLoop->new();
  my $evl = Milton::t::MockCondVar->new();
  $loop->_keyWatcher($evl);

  my $status = $loop->{history}->[-1];
  is($status->{key}, 'T', 'key is T');
  is($status->{event}, 'keyEvent', 'event is keyEvent');
  ref_is($status->{'event-loop'}, $loop, 'event-loop was provided');
  is($status->{now}, 0, 'now is 0');
  is($status->{time}, 0, 'time is 0');

  $loop->_keyWatcher($evl);

  $status = $loop->{history}->[-1];
  is($status->{key}, 'h', 'key is h');
  is($status->{event}, 'keyEvent', 'event is keyEvent');
  ref_is($status->{'event-loop'}, $loop, 'event-loop was provided');
  is($status->{now}, 1, 'now is 1');
  is($status->{time}, 1, 'time is 1');
};

done_testing;

my $string;
my $index;

BEGIN {
  $string = 'The quick brown fox jumps over the lazy dog';
  $index = 0;
  *Milton::EventLoop::ReadKey = \&ReadKey;
}

sub ReadKey {
  my ($self, $timeout) = @_;

  my $rc = substr($string, $index++, 1);

  return $rc;
}

1;
