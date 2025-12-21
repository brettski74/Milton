#!/usr/bin/perl

use strict refs;
use Milton::Config::Perl;

my %cfg;

my $DEPS = 
[ { name => 'AnyEvent'                    , version => '70.17', apt => 'perl-anyevent'         , apt => 'libanyevent-perl'          }
, { name => 'Clone'                       , version => '0.46' , apt => 'perl-clone'            , apt => 'libclone-perl'             }
, { name => 'Device::Modbus::RTU::Client' }
, { name => 'Device::SerialPort'          , version => '1.04' , apt => 'perl-device-serialport', apt => 'libdevice-serialport-perl' }
, { name => 'EV'                          , version => '4.34' , apt => 'perl-ev'               , apt => 'libev-perl'                }
, { name => 'Hash::Merge'                 , version => '0.302', apt => 'perl-hash-merge'       , apt => 'libhash-merge-perl'        }
, { name => 'Math::Round'                 , version => '0.07' , apt => 'perl-math-round'       , apt => 'libmath-round-perl'        }
, { name => 'Mojolicious::Lite'           }
, { name => 'Mojo::IOLoop::ReadWriteFork' }
, { name => 'Path::Tiny'                  , version => '0.148', apt => 'perl-path-tiny'        , apt => 'libpath-tiny-perl'         }
, { name => 'Readonly'                    , version => '2.05' , apt => 'perl-readonly'         , apt => 'libreadonly-perl'          }
, { name => 'Term::ReadKey'               , version => '2.38' , apt => 'perl-term-readkey'     , apt => 'libterm-readkey-perl'      }
, { name => 'YAML::PP'                    , version => '0.39' , apt => 'perl-uaml-pp'          , apt => 'libyaml-pp-perl'           }
, { name => 'YAML::PP::Schema::Include'   }
, { name => 'YAML::PP::Schema::Env'       }
];

sub prompt {
  my ($prompt, $default) = @_;
  chomp $prompt;

  print "$prompt [$default]\n";

  my $choice = <STDIN>;
  chomp $choice;

  if ($choice eq '' || !defined($choice)) {
    $choice = $default;
  }

  return $choice;
}

sub boolify {
  my ($value) = @_;

  return $value =~ /^(y|yes|true|1)$/i || 0;
}

my $shared_install = boolify(prompt(<<'EOS', 'no'));
Installing a shared instance may require sudo access and prompt for your password once or more during setup.

Install a shared instance?
EOS

print "We are not indented.\n";

# Ensure that target installation directory exists
if ($shared_install) {
  $cfg{MILTON_BASE} = '/opt/milton';
} else {
  $cfg{MILTON_BASE} = "$ENV{HOME}/.local/milton";
}

# Determine the available perl module installation methods
my $available_methods = Milton::Config::Perl::detect_module_installation_methods();

# Prompt for preferred perl module installation method

# Add fallback perl module installation methods

# Check perl version check strategy (ignore/warn/install)

# Check dependencies (installed and/or version appropriate)

# Install Milton Software

# Write the .miltonenv file

