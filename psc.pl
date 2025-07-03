#!/usr/bin/perl

use AnyEvent;
use Term::ReadKey;
use Getopt::Long qw(:config no_ignore_case bundling require_order);
use PowerSupplyControl::Config;
use PowerSupplyControl::EventLoop;

my $args = { config => 'psc.yaml' };
GetOptions($args, 'config=s', 'override=s@', 'library=s@');

my $command = shift;
PowerSupplyControl::Config->addSearchDir(@{$args->{library}}
                       , split(/:/, $ENV{PSC_CONFIG_PATH})
                       , '.'
                       , "$ENV{HOME}/.config/psc"
                       , '/usr/local/share/psc'
                       , '/usr/share/psc'
                       );

my $config = PowerSupplyControl::Config->new($args->{config});
if (PowerSupplyControl::Config->configFileExists('command/defaults.yaml')) {
  $config->merge('command/defaults.yaml', 'command', $command);
}
if (PowerSupplyControl::Config->configFileExists("command/$command.yaml")) {
  $config->merge("command/$command.yaml", 'command', $command);
}

my $evl = PowerSupplyControl::EventLoop->new($config, $command, @ARGV);

$evl->run;

exit(0);
