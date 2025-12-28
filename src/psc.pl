#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../lib/perl5";

use AnyEvent;
use Term::ReadKey;
use Getopt::Long qw(:config no_ignore_case bundling require_order);
use Milton::Config;
use Milton::EventLoop;
use Milton::Config::Utils;

my $args = { config => 'psc.yaml' };
GetOptions($args, qw( config=s
                     override=s@
                     library=s@
                     device=s
                     log=s@
                     logger=s
                     ambient=f
                     profile=s
                     reset
                     r0=s
                     cutoff=i
                     limit=s
                     ));

my $command = shift;
Milton::Config->addSearchDir(@{$args->{library}});
Milton::Config::Utils::standardSearchPath();

my $config = Milton::Config->new($args->{config});

if ($args->{logger}) {
   $config->{logger}->{package} = $args->{logger};
}

if (Milton::Config->configFileExists('command/defaults.yaml')) {
  $config->merge('command/defaults.yaml', 'command', $command);
}

# Merge in command configuration
if (Milton::Config->configFileExists("command/$command.yaml")) {
  $config->merge("command/$command.yaml", 'command', $command);
}

# Merge in any command configuration overrides
if (Milton::Config->configFileExists("command/$command-override.yaml")) {
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
  if (Milton::Config->configFileExists("device/$filename")) {
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

  if (Milton::Config->configFileExists("command/profile/$filename")) {
    $filename = "command/profile/$filename";
  }
  
  # Overwrite any existing profile. Don't merge. That appends onto the default profile.
  $config->{command}->{$command}->{profile} = Milton::Config->new($filename);
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

my $evl = Milton::EventLoop->new($config, $command, @ARGV);

my $controller = $evl->getController;

if ($args->{ambient}) {
  $evl->setAmbient($args->{ambient});
  $evl->{logger}->info("User supplied ambient temperature: $args->{ambient} °C");
}

if ($args->{reset}) {
  $controller->resetTemperatureCalibration(0);
}

if ($args->{r0}) {
  my ($r, $t) = split(/:/, $args->{r0}, 2);
  $t //= $args->{ambient} || 25;

  if ($r > 500) {
    # Assume that this is milliohms
    $r = $r / 1000;
  }

  $controller->resetTemperatureCalibration(0);
  $controller->setTemperaturePoint($t, $r);
}

if ($args->{cutoff}) {
  $evl->{logger}->info("Setting cutoff temperature to $args->{cutoff} °C");
  $controller->setCutoffTemperature($args->{cutoff});
}

if ($args->{limit}) {
  my ($t, $p) = split(/:/, $args->{limit}, 2);
  $evl->{logger}->info("Setting power limit at $t celsius going down to $p watts");
  $controller->setPowerLimit($t, $p);
}

$evl->run;

$evl->{logger}->info('update-delay: '. $evl->{interface}->getUpdateDelay);
  
exit(0);
