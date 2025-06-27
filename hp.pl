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
                       , split(/:/, $ENV{HP_CONFIG_PATH})
                       , '.'
                       , "$ENV{HOME}/.hotplate-config"
                       , '/usr/local/share/hotplate-config'
                       , '/usr/share/hotplate-config'
                       );

my $config = HP::Config->new($args->{config});
if (HP::Config->configFileExists('command/defaults.yaml')) {
  $config->merge('command/defaults.yaml', 'command', $command);
}
if (HP::Config->configFileExists("command/$command.yaml")) {
  $config->merge("command/$command.yaml", 'command', $command);
}

my $evl = HP::EventLoop->new($config, $command, @ARGV);

$evl->run;

exit(0);
