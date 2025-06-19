#!/usr/bin/perl

use AnyEvent;
use Term::ReadKey;

ReadMode('cbreak');

my $all_done = AnyEvent->condvar;

my $stdin_watcher;
$stdin_watcher = AnyEvent->io(fh => \*STDIN
                            , poll => 'r'
                            , cb => sub {
                              my $now = AnyEvent->now;
                              my $time = AnyEvent->time;

                              my $key = ReadKey(-1);

                              print "Pressed: $key, now = $now, time = $time\n" if defined $key;
                              if ($key eq 'q' || $key eq 'Q') {
                                $all_done->send;
                              }
                            }
                            );

my $timer;
$timer = AnyEvent->timer(after => 0
                       , interval => 1.5
                       , cb => sub {
                         my $now = AnyEvent->now;
                         my $time = AnyEvent->time;

                         print "Tick...now = $now, time = $time\n"; }
                       );

sub clean_exit {
  ReadMode('normal');
  exit(0);
}

my ($end_watcher, $quit_watcher);
$end_watcher = AnyEvent->signal(signal => 'INT', cb => \&clean_exit);
$end_watcher = AnyEvent->signal(signal => 'TERM', cb => \&clean_exit);
$quit_watcher = AnyEvent->signal(signal => 'QUIT', cb => \&clean_exit);

$all_done->recv;

clean_exit();

