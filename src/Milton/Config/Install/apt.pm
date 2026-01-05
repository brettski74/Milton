package Milton::Config::Install::apt;

use strict;
use warnings;
use base 'Milton::Config::Install';

=head1 NAME

Milton::Config::Install::apt - APT/dpkg installer for Perl modules

=head1 DESCRIPTION

Installs Perl modules using apt/dpkg on Debian/Ubuntu systems.
Requires sudo privileges.

=cut

sub is_available {
  my ($self) = @_;
  # Check if apt command exists and we're on a Debian-based system
  my $apt = system 'command -v apt >/dev/null 2>&1';
  return !$apt && -f '/etc/debian_version';
}

sub requires_sudo {
  return 1;  # apt requires sudo
}

sub _module_to_package {
  my ($self, $module) = @_;
  
  # Map common Perl modules to Debian package names
  my %module_map = (
    'AnyEvent' => 'libanyevent-perl',
    'Clone' => 'libclone-perl',
    'Device::SerialPort' => 'libdevice-serialport-perl',
    'EV' => 'libev-perl',
    'Hash::Merge' => 'libhash-merge-perl',
    'Math::Round' => 'libmath-round-perl',
    'Path::Tiny' => 'libpath-tiny-perl',
    'Readonly' => 'libreadonly-perl',
    'Term::ReadKey' => 'libterm-readkey-perl',
    'YAML::PP' => 'libyaml-pp-perl',
    'Test2::V0' => 'libtest2-suite-perl',
    'Module::ScanDeps' => 'libmodule-scandeps-perl',
  );
  
  # Convert Module::Name to Module-Name for lookup
  my $key = lc($module);
  $key =~ s/::/-/g;
  
  return $module_map{$module} || $module_map{$key} || "lib${key}-perl";
}

sub install {
  my ($self, $module) = @_;
  
  unless ($self->is_available()) {
    warn "apt is not available\n";
    return 0;
  }

  my $package = $self->_module_to_package($module);
  
  # Use sudo apt install
  return $self->execute('sudo', 'apt', 'install', '-y', $package);
}

1;

