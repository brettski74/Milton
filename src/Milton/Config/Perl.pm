package Milton::Config::Perl;

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';
use YAML::PP;
use Path::Tiny;

=head1 NAME

Milton::Config::Perl - Perl dependency checking and installation utilities

=head1 DESCRIPTION

Provides utilities for checking Perl dependencies and installing missing modules
using various installation methods (cpan, cpanm, apt, pacman, etc.).

=cut

my $CONFIG_FILE = "$ENV{HOME}/.config/milton/perl-deps.yaml";
my $CONFIG_BACKUP_DIR = "$ENV{HOME}/.config/milton";

=head1 FUNCTIONS

=head2 find_project_root()

Find the Milton project root directory by searching for Makefile or other markers.

=item Returns

Path to project root, or undef if not found.

=cut

sub find_project_root {
  my $cwd = abs_path('.');
  my @parts = File::Spec->splitdir($cwd);
  
  # Search up the directory tree
  for (my $i = $#parts; $i >= 0; $i--) {
    my $dir = File::Spec->catdir(@parts[0..$i]);
    my $makefile = File::Spec->catfile($dir, 'Makefile');
    my $readme = File::Spec->catfile($dir, 'README.md');
    
    # Check if this looks like the Milton root
    if (-f $makefile && -f $readme) {
      # Verify it's Milton by checking for src/Milton directory
      my $milton_dir = File::Spec->catdir($dir, 'src', 'Milton');
      if (-d $milton_dir) {
        return $dir;
      }
    }
  }
  
  return undef;
}

=head2 load_configuration()

Load configuration from YAML file, creating defaults if it doesn't exist.

=item Returns

Hash reference with configuration.

=cut

sub load_configuration {
  my $ypp = YAML::PP->new;
  my $config = {};
  
  if (-f $CONFIG_FILE) {
    eval {
      $config = $ypp->load_file($CONFIG_FILE);
      $config = {} unless ref($config) eq 'HASH';
    };
    if ($@) {
      warn "Error loading config file $CONFIG_FILE: $@\n";
      $config = {};
    }
  }
  
  # Set defaults
  $config->{preferred_method} ||= undef;
  $config->{last_updated} ||= undef;
  
  return $config;
}

=head2 save_configuration($config)

Save configuration to YAML file, backing up existing file.

=cut

sub save_configuration {
  my ($config) = @_;
  
  # Create config directory if it doesn't exist
  my $config_dir = dirname($CONFIG_FILE);
  Path::Tiny->new($config_dir)->mkpath unless -d $config_dir;
  
  # Backup existing file with timestamp
  if (-f $CONFIG_FILE) {
    my $timestamp = `date +%Y%m%d-%H%M%S`;
    chomp $timestamp;
    my $backup = "$CONFIG_FILE.$timestamp";
    rename($CONFIG_FILE, $backup) or warn "Could not backup config: $!\n";
    
    # Clean up old backups (keep only last 30 days, but always keep at least one)
    my @backups = glob("$CONFIG_FILE.*");
    if (@backups > 1) {
      my $cutoff = time - (30 * 24 * 60 * 60);  # 30 days ago
      for my $backup (@backups) {
        next if $backup eq "$CONFIG_FILE.$timestamp";  # Keep the new one
        my $mtime = (stat($backup))[9];
        if ($mtime < $cutoff) {
          unlink($backup) or warn "Could not remove old backup $backup: $!\n";
        }
      }
    }
  }
  
  # Update timestamp
  $config->{last_updated} = `date +%Y-%m-%d\ %H:%M:%S`;
  chomp $config->{last_updated};
  
  # Save new configuration
  my $ypp = YAML::PP->new;
  eval {
    $ypp->dump_file($CONFIG_FILE, $config);
  };
  if ($@) {
    die "Error saving config file $CONFIG_FILE: $@\n";
  }
}

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

=head2 prompt_for_preferred_method($available_methods)

Prompt user to select preferred installation method.

=over

=item $available_methods

Array reference of available installer objects.

=item Returns

Selected installer object, or undef if cancelled.

=back

=cut

sub prompt_for_preferred_method {
  my ($available_methods) = @_;
  
  unless (@$available_methods) {
    warn "No installation methods available!\n";
    return undef;
  }
  
  print "\nAvailable Perl module installation methods:\n";
  for (my $i = 0; $i < @$available_methods; $i++) {
    my $installer = $available_methods->[$i];
    my $name = $installer->name();
    my $sudo_note = $installer->requires_sudo() ? " (requires sudo)" : " (local install)";
    print "  " . ($i + 1) . ". $name$sudo_note\n";
  }
  print "\n";
  
  my $choice;
  while (1) {
    print "Select preferred method (1-" . scalar(@$available_methods) . "): ";
    $choice = <STDIN>;
    chomp $choice;
    
    if ($choice =~ /^\d+$/ && $choice >= 1 && $choice <= @$available_methods) {
      return $available_methods->[$choice - 1];
    }
    
    print "Invalid choice. Please enter a number between 1 and " . scalar(@$available_methods) . ".\n";
  }
}

=head2 check_scan_deps($installer)

Check if Module::ScanDeps is available, install it if missing.

=over

=item $installer

Installer object to use if installation is needed.

=item Returns

True if Module::ScanDeps is available, false otherwise.

=back

=cut

sub check_scan_deps {
  my ($installer) = @_;
  
  # Try to load Module::ScanDeps
  eval {
    require Module::ScanDeps;
  };
  
  if (!$@) {
    return 1;  # Already available
  }
  
  # Need to install it
  print "Module::ScanDeps is required but not found. Installing...\n";
  
  if ($installer && $installer->install('Module::ScanDeps')) {
    # Try loading again
    eval {
      require Module::ScanDeps;
    };
    return !$@;
  }
  
  return 0;
}

=head2 scan_deps($project_root)

Scan Perl files for dependencies and return unsatisfied modules.

=over

=item $project_root

Path to project root directory.

=item Returns

Array reference of unsatisfied module names.

=back

=cut

sub scan_deps {
  my ($project_root) = @_;
  
  unless ($project_root && -d $project_root) {
    die "Invalid project root: $project_root\n";
  }
  
  # Check for Module::ScanDeps
  eval {
    require Module::ScanDeps;
  };
  
  if ($@) {
    die "Module::ScanDeps is not available. Run check_scan_deps() first.\n";
  }
  
  my @files = ();
  
  # Find all .pm and .pl files in src/ and webui/
  for my $dir (qw(src webui)) {
    my $dir_path = File::Spec->catdir($project_root, $dir);
    next unless -d $dir_path;
    
    my $find_cmd = "find '$dir_path' -type f \\( -name '*.pm' -o -name '*.pl' \\) 2>/dev/null";
    open my $fh, '-|', $find_cmd or next;
    while (my $file = <$fh>) {
      chomp $file;
      push @files, $file if -f $file;
    }
    close $fh;
  }
  
  unless (@files) {
    warn "No Perl files found to scan\n";
    return [];
  }
  
  # Scan dependencies using static analysis (doesn't require loading modules)
  my %deps = ();
  for my $file (@files) {
    # Use scan_deps for static analysis - doesn't require modules to be installed
    my $info = Module::ScanDeps::scan_deps($file);
    if ($info && ref($info) eq 'HASH') {
      for my $module (keys %$info) {
        # Skip core modules and modules that are part of the project
        next if $module =~ /^(Milton|BLE)::/;
        next if $module eq 'main';
        $deps{$module} = 1;
      }
    }
  }
  
  # Check which dependencies are actually missing
  my @missing = ();
  for my $module (sort keys %deps) {
    eval "require $module";
    if ($@) {
      push @missing, $module;
    }
  }
  
  return \@missing;
}

=head2 install_modules($modules, $preferred_installer, $fallback_installers)

Install a list of Perl modules.

=over

=item $modules

Array reference of module names to install.

=item $preferred_installer

Preferred installer object to use.

=item $fallback_installers

Array reference of fallback installer objects to try if preferred fails.

=item Returns

Array reference of module names that failed to install.

=back

=cut

sub install_modules {
  my ($modules, $preferred_installer, $fallback_installers) = @_;
  
  $fallback_installers ||= [];
  my @failed = ();
  
  for my $module (@$modules) {
    print "Installing $module...\n";
    my $success = 0;
    
    # Try preferred method first
    if ($preferred_installer) {
      $success = $preferred_installer->install($module);
    }
    
    # Try fallback methods if preferred failed
    if (!$success && $preferred_installer && 
        ($preferred_installer->requires_sudo() || 
         $preferred_installer->name() eq 'apt' || 
         $preferred_installer->name() eq 'pacman')) {
      # Preferred method requires sudo or is a package manager, try local installers
      for my $fallback (@$fallback_installers) {
        next if $fallback->requires_sudo();  # Skip sudo-requiring fallbacks
        $success = $fallback->install($module);
        last if $success;
      }
    }
    
    if ($success) {
      print "  ✓ Successfully installed $module\n";
    } else {
      print "  ✗ Failed to install $module\n";
      push @failed, $module;
    }
  }
  
  return \@failed;
}

1;
