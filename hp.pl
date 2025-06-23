#!/usr/bin/perl

use AnyEvent;
use Term::ReadKey;
use Getopt::Long qw(:config no_ignore_case bundling require_order);
use HP::Config;
use HP::EventLoop;

my $args = { config => 'hp.yaml' };
GetOptions($args, 'config=s', 'library=s@');

my $command = shift;
HP::Config->addSearchDir(@{$args->{library}}
                       , "$ENV{HOME}/hp"
                       , "/etc/hp"
                       );

my $config = HP::Config->new($args->{config});

my $evl = HP::EventLoop->new($config, $command, @ARGV);

$evl->run;

exit(0);
