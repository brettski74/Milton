#!/usr/bin/perl

use AnyEvent;
use Term::ReadKey;
use Getopt::Long qw(:config no_ignore_case bundling require_order);
use PowerSupplyControl::Config;
use PowerSupplyControl::EventLoop;

my $args = { config => 'psc.yaml' };
GetOptions($args, 'config=s', 'override=s@', 'library=s@', 'device=s', 'log=s@', 'logger=s', 'ambient=f', 'profile=s', 'reset', 'r0=s');

my $command = shift;
PowerSupplyControl::Config->addSearchDir(@{$args->{library}}
                       , split(/:/, $ENV{PSC_CONFIG_PATH})
                       , '.'
                       , "$ENV{HOME}/.config/psc"
                       , "$ENV{HOME}/.local/share/psc"
                       , '/usr/local/share/psc'
                       , '/usr/share/psc'
                       );

my $config = PowerSupplyControl::Config->new($args->{config});

if ($args->{logger}) {
   $config->{logger}->{package} = $args->{logger};
}

if (PowerSupplyControl::Config->configFileExists('command/defaults.yaml')) {
  $config->merge('command/defaults.yaml', 'command', $command);
}

# Merge in command configuration
if (PowerSupplyControl::Config->configFileExists("command/$command.yaml")) {
  $config->merge("command/$command.yaml", 'command', $command);
}

# Merge in any command configuration overrides
if (PowerSupplyControl::Config->configFileExists("command/$command-override.yaml")) {
  $config->merge("command/$command-override.yaml");
}

# Merge in any command line overrides
if ($args->{override}) {
  foreach my $override (@{$args->{override}}) {
    my $filename = $override;
    my @keys = ();
    if ($override =~ /^([^:]+):(.*)$/) {
      $filename = $2;
      @keys = split /\./,$1;
    }

    if ($filename !~ /\.yaml$/) {
      $filename .= '.yaml';
    }

    $config->merge($filename, @keys);
  }
}

# Merge in any device configuration
if ($args->{device}) {
  my $filename = $args->{device};
  if ($filename !~ /\.yaml$/) {
    $filename .= '.yaml';
  }

  # Search in the device subdirectory, first, then try the current directory as a fallback
  if (PowerSupplyControl::Config->configFileExists("device/$filename")) {
    $filename = "device/$filename";
  }

  $config->merge($filename, qw(controller device));
}

# Check for a profile specifier
if ($args->{profile}) {
  my $filename = $args->{profile};
  if ($filename !~ /\.yaml$/) {
    $filename .= '.yaml';
  }

  if (PowerSupplyControl::Config->configFileExists("command/profile/$filename")) {
    $filename = "command/profile/$filename";
  }
  
  # Overwrite any existing profile. Don't merge. That appends onto the default profile.
  $config->{command}->{$command}->{profile} = PowerSupplyControl::Config->new($filename);
}

# Add any extra logging columns
if ($args->{log}) {
  foreach my $log (@{$args->{log}}) {
    my ($key, $format) = split(/:/, $log, 2);

    my $record = { key => $key };
    $record->{format} = $format if $format;

    push @{$config->{logging}->{columns}}, $record;
  }
}

my $evl = PowerSupplyControl::EventLoop->new($config, $command, @ARGV);

if ($args->{ambient}) {
  $evl->setAmbient($args->{ambient});
}

if ($args->{reset}) {
  $evl->getController->resetTemperatureCalibration(0);
}

if ($args->{r0}) {
  my ($r, $t) = split(/:/, $args->{r0}, 2);
  $t //= $args->{ambient} || 25;

  if ($r > 500) {
    # Assume that this is milliohms
    $r = $r / 1000;
  }

  $evl->getController->resetTemperatureCalibration(0);
  $evl->getController->setTemperaturePoint($t, $r);
}

$evl->run;

$evl->{logger}->info('update-delay: '. $evl->{interface}->getUpdateDelay);
  
exit(0);
