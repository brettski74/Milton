#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use Milton::Config::Perl;

=head1 NAME

check_deps.pl - Check and install Perl dependencies for Milton

=head1 SYNOPSIS

    check_deps.pl [--auto-install] [--preferred-method METHOD]

=head1 DESCRIPTION

Scans Milton source code for Perl dependencies and optionally installs
missing modules using the user's preferred installation method.

=cut

my $auto_install = 0;
my $preferred_method_name = undef;

# Parse command line arguments
for my $arg (@ARGV) {
  if ($arg eq '--auto-install' || $arg eq '-a') {
    $auto_install = 1;
  } elsif ($arg =~ /^--preferred-method=(.+)$/) {
    $preferred_method_name = $1;
  } elsif ($arg eq '--help' || $arg eq '-h') {
    print <<EOF;
Usage: $0 [options]

Options:
    --auto-install, -a          Automatically install missing dependencies
    --preferred-method=METHOD   Use specified installation method
                                (cpanm, cpan, apt, pacman)
    --help, -h                  Show this help message

This script scans the Milton source code for Perl dependencies and
reports (and optionally installs) missing modules.

EOF
    exit 0;
  }
}

# Find project root
print "Finding project root...\n";
my $project_root = Milton::Config::Perl::find_project_root();

unless ($project_root) {
  die "Could not find Milton project root. Please run this script from within the Milton source tree.\n";
}

print "Project root: $project_root\n\n";

# Load configuration
print "Loading configuration...\n";
my $config = Milton::Config::Perl::load_configuration();

# Detect available installation methods
print "Detecting available installation methods...\n";
my $available_methods = Milton::Config::Perl::detect_module_installation_methods();

unless (@$available_methods) {
  die "No Perl module installation methods are available on this system.\n";
}

print "Found " . scalar(@$available_methods) . " available method(s)\n\n";

# Determine preferred installer
my $preferred_installer = undef;

if ($preferred_method_name) {
  # User specified method on command line
  for my $installer (@$available_methods) {
    if ($installer->name() eq $preferred_method_name) {
      $preferred_installer = $installer;
      last;
    }
  }
  
  unless ($preferred_installer) {
    die "Specified method '$preferred_method_name' is not available.\n";
  }
} elsif ($config->{preferred_method}) {
  # Use saved preference
  for my $installer (@$available_methods) {
    if ($installer->name() eq $config->{preferred_method}) {
      $preferred_installer = $installer;
      last;
    }
  }
  
  # If saved preference is no longer available, prompt again
  unless ($preferred_installer) {
    print "Previously preferred method '$config->{preferred_method}' is no longer available.\n";
    $preferred_installer = Milton::Config::Perl::prompt_for_preferred_method($available_methods);
    if ($preferred_installer) {
      $config->{preferred_method} = $preferred_installer->name();
      Milton::Config::Perl::save_configuration($config);
    }
  }
} else {
  # No preference set, prompt user
  $preferred_installer = Milton::Config::Perl::prompt_for_preferred_method($available_methods);
  if ($preferred_installer) {
    $config->{preferred_method} = $preferred_installer->name();
    Milton::Config::Perl::save_configuration($config);
  }
}

unless ($preferred_installer) {
  die "No installation method selected.\n";
}

print "Using installation method: " . $preferred_installer->name() . "\n\n";

# Check for Module::ScanDeps
print "Checking for Module::ScanDeps...\n";
unless (Milton::Config::Perl::check_scan_deps($preferred_installer)) {
  die "Failed to install Module::ScanDeps, which is required for dependency scanning.\n";
}
print "Module::ScanDeps is available.\n\n";

# Scan for dependencies
print "Scanning for Perl dependencies...\n";
my $missing = Milton::Config::Perl::scan_deps($project_root);

if (!@$missing) {
  print "All dependencies are satisfied!\n";
  exit 0;
}

print "Found " . scalar(@$missing) . " missing dependency(ies):\n";
for my $module (@$missing) {
  print "  - $module\n";
}
print "\n";

# Install missing dependencies if requested
if ($auto_install) {
  print "Installing missing dependencies...\n\n";
  
  # Get fallback installers (local installers if preferred requires sudo)
  my @fallbacks = ();
  if ($preferred_installer->requires_sudo()) {
    for my $installer (@$available_methods) {
      next if $installer->requires_sudo();
      push @fallbacks, $installer;
    }
  }
  
  my $failed = Milton::Config::Perl::install_modules(
    $missing,
    $preferred_installer,
    \@fallbacks
  );
  
  print "\n";
  
  if (!@$failed) {
    print "All dependencies installed successfully!\n";
    exit 0;
  } else {
    print "Failed to install " . scalar(@$failed) . " module(s):\n";
    for my $module (@$failed) {
      print "  - $module\n";
    }
    exit 1;
  }
} else {
  print "Run with --auto-install to automatically install missing dependencies.\n";
  exit 1;
}

