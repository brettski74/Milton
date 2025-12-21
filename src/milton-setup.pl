#!/usr/bin/perl

use strict refs;

my %cfg;

my $DEPS = 
[ { name => 'AnyEvent'                    , version => '70.17', pacman => 'perl-anyevent'         , apt => 'libanyevent-perl'          }
, { name => 'Clone'                       , version => '0.46' , pacman => 'perl-clone'            , apt => 'libclone-perl'             }
, { name => 'Device::Modbus::RTU::Client' }
, { name => 'Device::SerialPort'          , version => '1.04' , pacman => 'perl-device-serialport', apt => 'libdevice-serialport-perl' }
, { name => 'EV'                          , version => '4.34' , pacman => 'perl-ev'               , apt => 'libev-perl'                }
, { name => 'Hash::Merge'                 , version => '0.302', pacman => 'perl-hash-merge'       , apt => 'libhash-merge-perl'        }
, { name => 'Math::Round'                 , version => '0.07' , pacman => 'perl-math-round'       , apt => 'libmath-round-perl'        }
, { name => 'Mojolicious::Lite'           }
, { name => 'Mojo::IOLoop::ReadWriteFork' }
, { name => 'Path::Tiny'                  , version => '0.148', pacman => 'perl-path-tiny'        , apt => 'libpath-tiny-perl'         }
, { name => 'Readonly'                    , version => '2.05' , pacman => 'perl-readonly'         , apt => 'libreadonly-perl'          }
, { name => 'Term::ReadKey'               , version => '2.38' , pacman => 'perl-term-readkey'     , apt => 'libterm-readkey-perl'      }
, { name => 'YAML::PP'                    , version => '0.39' , pacman => 'perl-uaml-pp'          , apt => 'libyaml-pp-perl'           }
, { name => 'YAML::PP::Schema::Include'   }
, { name => 'YAML::PP::Schema::Env'       }
];

=head2 detect_module_installation_methods()

Detect available module installation methods.

=item Returns

Array reference of available installer objects.

=cut

sub detect_module_installation_methods {
  my @available = ();
  
  # Try to load installer classes
  # Order is important. First detected method will be default preferred method.
  for my $method (qw(pacman apt cpanm cpan)) {
    my $class = "Milton::Config::Install::$method";
    eval "use $class";
    if (!$@) {
      my $installer = $class->new();
      if ($installer->is_available()) {
        push @available, $installer;
      }
    }
  }
  
  return \@available;
}

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

sub find_by_name {
  my ($value, $array) = @_;

  foreach my $item (@$array) {
    if ($item->name eq $value) {
      return $item;
    }
  }
  return;
}

sub boolify {
  my ($value) = @_;

  return $value =~ /^(y|yes|true|1)$/i || 0;
}

my $shared_install = boolify(prompt(<<'EOS', 'no'));
Installing a shared instance may require sudo access and prompt for your password once or more during setup.

Install a shared instance?
EOS

# Ensure that target installation directory exists
if ($shared_install) {
  $cfg{MILTON_BASE} = '/opt/milton';
} else {
  $cfg{MILTON_BASE} = "$ENV{HOME}/.local/milton";
}

# Determine the available perl module installation methods
my $available_methods = detect_module_installation_methods();
my $method_list = join("\n    ", map { $_->name() } sort { $a->name cmp $b->name } @$available_methods);

# Prompt for preferred perl module installation method
my @methods;
while (!defined $methods[0]) {
  my $method = prompt(<<"EOS", $available_methods->[0]->name());
The following methods are available for installing perl modules:

    $method_list

Select your preferred primary method for installing perl modules.
EOS

  if (!defined $method || ! find_by_name($method, $available_methods)) {
    print "Invalid method \"$method\". Please select a valid method.\n";
    $method = undef;
  } else {
    $methods[0] = find_by_name($method, $available_methods);
  }
}


# Add fallback perl module installation methods
my @fallback;
push @fallback, find_by_name('cpanm', $available_methods) unless $preferred_method eq 'cpanm';
push @fallback, find_by_name('cpan', $available_methods) unless $preferred_method eq 'cpan';

print "Perl installation methods: ". join(', ', map { $_->name() } @fallback). "\n";

# Check perl version check strategy (ignore/warn/install)

# Check dependencies (installed and/or version appropriate)
foreach my $dependency (@$DEPS) {
  METHOD: foreach my $method (@methods) {
    print 'Checking dependency: '.$dependency->{name}.'...  ';

    eval "use $dependency->{name}";
    if ($@) {
      print "not found\n";

      $method->install($dependency->{name});
    } else {
      print "found\n";
      last METHOD;
    }
  }
}

# Install Milton Software

# Write the .miltonenv file

