#!/usr/bin/perl

use strict refs;
use FindBin qw($RealBin);

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

=item Return Value

Reference to an array containing installer objects for supported perl installation methods.

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

=head2 system_exec(@command)

Execute a command and return the exit code.

=over

=item @command

The command and arguments to execute.

=item Return Value

The exit code of the command.

=back

=cut

sub system_exec {
  my (@command) = @_;
  print join(' ', @command) ."\n";
  return system(@command);
}

=head2 prompt($prompt, $default)

Display a message to the user and wait for them to enter a value.

If they enter a blank response, then return the default value.

=over

=item $prompt

The message to display to the user.

=item $default

The default value to return if the user enters a blank response.

=item Return Value

The value entered by the user or the default value if they entered a blank response.

=back

=cut

sub prompt {
  my ($prompt, $default) = @_;
  chomp $prompt;

  print "$prompt ";
  
  if (defined($default)) {
    print "[$default]";
  }
  
  print "\n";

  my $choice = <STDIN>;
  chomp $choice;
  $choice =~ s/^\s+//;
  $choice =~ s/\s+$//;

  if ($choice eq '' || !defined($choice)) {
    $choice = $default;
  }

  return $choice;
}

=head2 find_by_name($value, $array)

Find an item in an array of hashes based on the value associated with the name key.

=over

=item $value

The name of the value to find.

=item $array

A reference to an array of hashes.

=item Return Value

The matching hash, if found, otherwise returns false.

=back

=cut

sub find_by_name {
  my ($value, $array) = @_;

  foreach my $item (@$array) {
    if ($item->name eq $value) {
      return $item;
    }
  }
  return;
}

=head2 boolify($value)

Convert an arbitrary value into a normalized boolean value - ie. either 1 or 0.

=over

=item $value

The value to be converted to a normalized boolean value.

=item Return Value

1 if $value evaluates as true, otherwise 0.

=back

=cut

sub boolify {
  my ($value) = @_;

  return $value =~ /^(y|yes|true|1)$/i || 0;
}

=head2 copy_file($source, $destination)

Copy a file from the source to the destination.

=over

=item $source

The source file to copy.

=item $destination

The destination file to copy to.

=back

=cut

sub copy_file {
  my ($source, $destination) = @_;
  system_exec 'cp', '-v', $source, $destination;
}

sub startsWith {
  my ($string, $prefix) = @_;
  return substr($string, 0, length($prefix)) eq $prefix;
}

###
### Determine MILTON_BASE if it's not set, but without the benefit of Milton::Config::Path, since we may not be able to find it yet.
### Can't check if the MILTON_BASE directory exists yet, since it may not have been created if installing from source.
###
if (!defined $ENV{MILTON_BASE}) {
  my $milton_base = $RealBin;
  if ($milton_base =~ /\/bin$/) {
    if (-f "$RealBin/milton-setup" && -f "$RealBin/milton" && -f "$RealBin/psc") {
      $milton_base =~ s/\/bin$//;
      $ENV{MILTON_BASE} = $milton_base;
    }
  } elsif ($milton_base =~ /\/src$/) {
    if (-f '$RealBin/../install.sh') {
      exec '$RealBin/../install.sh';
    }
  }
}

if (!defined $ENV{MILTON_BASE}) {
  die "Unable to determine MILTON_BASE. Consider manually setting the MILTON_BASE environment variable before attempting to run this script again.\n";
}

my $shared_install;

# Check if this is a shared installation.
if (startsWith($ENV{MILTON_BASE}, $ENV{HOME})) {
  $shared_install = 0;
} else {
  $shared_install = 1;

  ###
  ### Ensure that the target installation directory exists.
  ###
  if (!-d $MILTON_BASE) {
    system_exec 'sudo', 'mkdir', '-p', $ENV{MILTON_BASE};
    system_exec 'sudo', 'chown', $ENV{USER}, $ENV{MILTON_BASE};
    system_exec 'sudo', 'chmod', '755', $ENV{MILTON_BASE};
  }
}

###
### Make sure that we can load libraries from the target installation directory.
###
eval "use lib '$ENV{MILTON_BASE}/lib/perl5'";
$ENV{PERL5LIB} = "$ENV{MILTON_BASE}/lib/perl5:$ENV{PERL5LIB}";

###
### Determine the available perl library installation methods for perl dependencies.
###
my $available_methods = detect_module_installation_methods();
my $method_list = join("\n    ", map { $_->name() } sort { $a->name cmp $b->name } @$available_methods);

# Prompt for preferred perl module installation method
my @methods;
while (!defined $methods[0]) {
  my $method = prompt(<<"EOS", $available_methods->[0]->name());
################################################################################
################################################################################
################################################################################
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

###
### Add fallback perl module installation methods - cpanm and cpan, if available.
###
push @methods, find_by_name('cpanm', $available_methods) unless $preferred_method eq 'cpanm';
push @methods, find_by_name('cpan', $available_methods) unless $preferred_method eq 'cpan';

foreach my $method (@methods) {
  $method->set_install_path($ENV{MILTON_BASE});
}

print "Perl installation methods: ". join(', ', map { $_->name() } @methods). "\n";

###
### TODO: Ask which perl version check strategy to use - ignore/warn/install.
###

###
### Ensure that all perl dependencies are installed.
###
foreach my $dependency (@$DEPS) {
  my $installed = 0;
  METHOD: foreach my $method (@methods) {
    print 'Checking dependency: '.$dependency->{name}.'...  ';

    eval "use $dependency->{name}";
    if ($@) {
      print "not found\n";

      $method->install($dependency->{name});
    } else {
      print "found\n";
      $installed = 1;
      last METHOD;
    }
  }
  if (!$installed) {
    print <<"EOS";
################################################################################
FATAL ERROR: Unable to install dependency: $dependency->{name}.

Possible solutions:

1. Resolve missing dependencies. Some perl modules are not available in your
distribution's standard package repositories and require installation from
source using cpan or cpanm. Consider installing the following packages to ensure
that these modules can be built and installed.

On Debian based systems:

    sudo apt install make gcc cpanminus liblocal-lib-perl

On Arch based systems

    sudo pacman -S make gcc cpanminus perl-local-lib

2. If you are using cpan or cpanm as your primary installation method, you may
have more success installing from the distribution repositories where possible.
This requires that you have sudo access, but consider using the pacman or apt
installation method as your primary installation method.

3. Install the module manually, resolve any errors that occur and then retry the
milton-setup again.

EOS

    if ($dependency->{apt}) {
      print <<"EOS";
On Debian based systems:

    sudo apt install $dependency->{apt}

EOS
    }

    if ($dependency->{pacman}) {
      print <<"EOS";
On Arch based systems:

    sudo pacman -S $dependency->{pacman}

EOS
    }

    print <<"EOS";
Using cpan or cpanm, one of the following commands:

    cpanm -L $ENV{MILTON_BASE} $dependency->{name}

    perl -Mlocal::lib=$ENV{MILTON_BASE} -MCPAN -e "install $dependency->{name}"

EOS

    die "Unable to install dependency: ". $dependency->{name} .". Please install it manually and try again.\n";
  }
}

###
### Set up config.mk if not already present.
###
my $config_mk = $shared_install ? 'config.mk.global' : 'config.mk.local';
if ( -f 'Makefile' && -f $config_mk && -f ! -f 'config.mk' ) {
  copy_file $config_mk, 'config.mk';
}

###
### Install Milton Software if required
###
if ( -e './install.sh' && -e './Makefile' ) {
  system_exec 'make', 'install-dirs', 'install', 'install-config';
}

# Load required modules now that we can be confident that they're installed.
eval <<'EOS';
use lib "$ENV{MILTON_BASE}/lib/perl5";

use Milton::Interface::Utils::SCPIScanner;
use Milton::Config::Template;
use IO::File;
use Path::Tiny;
EOS

###
### Figure out the power supply interface details
###
print <<'EOS';
################################################################################
################################################################################
################################################################################
We need to determine how to connect to your power supply. Do you wish to:

  1) Scan for supported power supplies (Recommended)
  2) Select a supported power supply from a list of known, supported power supplies.
  3) Manually edit the configuration after installation.
EOS
my $choice;
while ($choice < 1 || $choice > 3) {
  $choice = prompt('Selection (1, 2 or 3)?', '1');
  chomp $choice;
}

my $scanner = Milton::Interface::Utils::SCPIScanner->new();

my $template = Milton::Config::Template->new(template => 'psc.yaml.template');
$template->setParameterValue('interface-config', 'interface/user.yaml');

my $edit = 1;
my $interface;

if ($choice == 1) {
  $interface = scan_for_power_supplies($scanner, $template);

  if ($interface) {
    $template->setParameterValue('interface-config', $interface);
    $edit = undef;
  }
} elsif ($choice == 2) {
  $interface = select_power_supply($scanner, $template);

  if ($interface) {
    $template->setParameterValue('interface-config', $interface);
    $edit = undef;
  }
}

$template->render();

if ($edit) {
  system_exec 'mledit';
}

sub scan_for_power_supplies {
  my ($scanner) = @_;
  print <<'EOS';
################################################################################
################################################################################
################################################################################
We will now scan for a SCPI power supply. Please ensure that your power supply
is:

  1) Connected to your computer
  2) Powered on
  3) Disconnected from any load

It is advisable to power off or disconnect any other test equipment that may
currently be connected to your computer to minimize the risk of unintended
consequences or detecting an unwanted instrument.

The scan may require user input from time to time, so remain nearby in case user
input is require.

Press ENTER when you are ready to commence the scan.
EOS
  <STDIN>;

  my @found = $scanner->scanSCPIDevices();
  my $extra='';

  if (@found) {
    print "The following power supplies were found:\n";

    foreach my $i (0..$#found) {
      printf "  %d) %s (%s)\n", $i + 1, $found[$i]->{displayName}, $found[$i]->{device};
    }

    if (@found > 1) {
      $extra = ' or 1-'.scalar(@found);
    } elsif(@found == 1) {
      $extra = ' or 1';
    }

  } else {
    print "No power supplies were found. Would you like to:\n\n";
  }

  print <<'EOS';
  S) Select from a list of supported instruments instead
  M) Manually edit the configuration after installation

EOS

  my $choice;
  while ($choice ne 'S' && $choice ne 'M' && ($choice < 1 || $choice > @found)) {
    $choice = uc(prompt('Selection (S or M'.$extra.')?', 'S'));
  }

  if ($choice eq 'S') {
    return select_power_supply($scanner);
  } elsif ($choice eq 'M') {
    return
  }

  return $found[$choice - 1]->{value};
}

sub select_power_supply {
  my ($scanner) = @_;

  # Shallow copy so we can remove the serial and usbtmc hashes, since they're not manufacturers.
  my $devices = { %{$scanner->{devices}} };
  delete $devices->{serial};
  delete $devices->{usbtmc};

  my @manufacturers = sort keys %$devices;

  print "Select from the following manufacturers:\n\n";

  for(my $i =0; $i < @manufacturers; $i++) {
    printf "  %d) %s\n", $i + 1, $manufacturers[$i];
  }

  print "  S) Scan for a supported power supply instead\n";
  print "  M) Manually edit the configuration after installation\n\n";

  my $choice;
  while ($choice ne 'S' && $choice ne 'M' && ($choice < 1 || $choice > @manufacturers)) {
    my $extra = 1;
    if (@manufacturers > 1) {
      $extra .= '-'.scalar(@manufacturers);
    }
    $choice = uc(prompt('Selection (S or M or '.$extra.')?', 'S'));
  }

  if ($choice eq 'S') {
    return scan_for_power_supplies($scanner, $manufacturer);
  } elsif ($choice eq 'M') {
    return;
  }

  return select_power_supply_model($scanner, $manufacturers[$choice - 1]);
}

sub select_power_supply_model {
  my ($scanner, $manufacturer) = @_;

  my $devices = $scanner->{devices}->{$manufacturer};
  my @models = sort { $a->{displayName} cmp $b->{displayName} } @$devices;

  print "Select from the following models:\n\n";

  for(my $i =0; $i < @models; $i++) {
    printf "  %d) %s\n", $i + 1, $models[$i]->{displayName};
  }
  
  print "  S) Scan for a supported power supply instead\n";
  print "  M) Manually edit the configuration after installation\n\n";

  my $choice;
  while ($choice ne 'S' && $choice ne 'M' && ($choice < 1 || $choice > @models)) {
    my $extra = 1;
    if (@models > 1) {
      $extra .= '-'.scalar(@models);
    }
    $choice = uc(prompt('Selection (S or M or '.$extra.')?', 'S'));
  }

  if ($choice eq 'S') {
    return scan_for_power_supply_models($scanner);
  } elsif ($choice eq 'M') {
    return;
  }

  return @models[$choice - 1]->{value};
}

my $miltonenv_path = "$ENV{HOME}/.miltonenv";
my $miltonenv = IO::File->new($miltonenv_path, 'w');
if ($miltonenv) {
  my $homelen = length($ENV{HOME});
  if ($homelen > 0 && $ENV{HOME} eq substr($ENV{MILTON_BASE}, 0, $homelen)) {
    $miltonenv->print('MILTON_BASE=$HOME/'. substr($ENV{MILTON_BASE}, $homelen+1). "\n");
  } else {
    $miltonenv->print("MILTON_BASE=$ENV{MILTON_BASE}\n");
  }
  $miltonenv->print('PATH=$MILTON_BASE/bin:$PATH' . "\n");
  $miltonenv->print("export MILTON_BASE PATH\n");
  $miltonenv->close;
} else {
  warn "Failed to open $miltonenv_path for writing: $!";
}

if ($shared_install) {
  my ($dev, $ino, $mode, $nlink, $uid, $gid) = stat($ENV{MILTON_BASE}/bin/milton);
  my $user = getpwuid($uid);
  my $group = getgrgid($gid);

  print <<"EOS";
The milton installation appears to be owned by $user:$group. What user and/or
group should own the installation?
EOS

  my $default = "$user:$group";
  my $choice;
  while (!defined($choice) || $choice ne '') {
    $choice = prompt('Enter the user:group that should own the installation', $default);
    if ($choice eq $default) {
      $choice = undef;
      last;
    }

    my ($new_user, $new_group) = split(/:/, $choice, 2);
    my $new_uid = getpwnam($new_user);
    if (!$new_uid) {
      print "Invalid user: $new_user\n";
      $choice = undef;
      next;
    }

    if ($choice =~ /:/) {
      my $new_gid = getgrnam($new_group);
      if (!$new_gid) {
        print "Invalid group: $new_group\n";
        $choice = undef;
        next;
      }
    }
  }

  if ($choice) {
    system_exec 'sudo', 'chown', '-R', $choice, $ENV{MILTON_BASE};
  }
}

print <<'EOS';
################################################################################
################################################################################
################################################################################
Installation is complete, however you may wish to ensure that your path is
updated to include Milton's binaries. The file .miltonenv in your home directory
can be sourced in your profile for this purpose.

You will likely need to do some calibration of your hotplate before you can
accurately measure or control its temperature. Please see the instructions on
calibration at https://github.com/brettski74/Milton/CALIBRATION.md

If you still need instructions on how to setup and assemble your hotplate, you
can find more resources on this at https://github.com/brettski74/Milton/resources

You can start the Milton web interface by running the command:

    milton daemon

or if you want to start it on a port other than the default port of 3000, you
can use:

    milton daemon -l http://*:4000

Issues can be reported at https://github.com/brettski74/Milton/issues

Thank you for using Milton!
EOS

# Write the .miltonenv file

