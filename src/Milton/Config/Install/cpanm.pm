package Milton::Config::Install::cpanm;

use strict;
use warnings;
use base 'Milton::Config::Install';

=head1 NAME

Milton::Config::Install::cpanm - cpanminus installer for Perl modules

=head1 DESCRIPTION

Installs Perl modules using cpanminus (cpanm). Installs modules locally
for the current user only.

=cut

sub is_available {
  my ($self) = @_;
  # Check if cpanm command exists
  my $cpanm = `which cpanm 2>/dev/null`;
  chomp $cpanm;
  return $cpanm && -x $cpanm;
}

sub requires_sudo {
  return 0;  # cpanm installs locally
}

sub set_install_path {
  my ($self, $path) = @_;
  $self->{install_path} = $path;
}

sub install {
  my ($self, $module) = @_;
  
  unless ($self->is_available()) {
    warn "cpanm is not available\n";
    return 0;
  }

  my @extra;
  if ($self->{install_path}) {
    push @extra, '-L', $self->{install_path};
  }

  # Use cpanm to install module locally
  # cpanm installs to ~/perl5 by default when not run as root
  return $self->execute('cpanm', @extra, $module);
}

1;

