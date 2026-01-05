package Milton::Config::Install::pacman;

use strict;
use warnings;
use base 'Milton::Config::Install';

=head1 NAME

Milton::Config::Install::pacman - pacman installer for Perl modules

=head1 DESCRIPTION

Installs Perl modules using pacman on Arch Linux systems.
Requires sudo privileges.

=cut

sub is_available {
  my ($self) = @_;
  # Check if pacman command exists and we're on an Arch-based system
  my $pacman = system 'command -v pacman >/dev/null 2>&1';
  return !$pacman && -f '/etc/arch-release';
}

sub requires_sudo {
  return 1;  # pacman requires sudo
}

sub _module_to_package {
  my ($self, $module) = @_;
  
  # Map common Perl modules to Arch package names
  my %module_map = (
    'AnyEvent' => 'perl-anyevent',
    'Clone' => 'perl-clone',
    'Device::SerialPort' => 'perl-device-serialport',
    'EV' => 'perl-ev',
    'Hash::Merge' => 'perl-hash-merge',
    'Math::Round' => 'perl-math-round',
    'Path::Tiny' => 'perl-path-tiny',
    'Readonly' => 'perl-readonly',
    'Term::ReadKey' => 'perl-term-readkey',
    'YAML::PP' => 'perl-yaml-pp',
    'Test2::V0' => 'perl-test2-suite',
    'Module::ScanDeps' => 'perl-module-scandeps',
  );
  
  # Convert Module::Name to Module-Name for lookup
  my $key = $module;
  $key =~ s/::/-/g;
  
  return $module_map{$module} || $module_map{$key} || "perl-${key}";
}

sub install {
  my ($self, $module) = @_;
  
  unless ($self->is_available()) {
    warn "pacman is not available\n";
    return 0;
  }

  my $package = $self->_module_to_package($module);
  
  # Use sudo pacman -S --noconfirm
  return $self->execute('sudo', 'pacman', '-S', '--noconfirm', $package);
}

1;

