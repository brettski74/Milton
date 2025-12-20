package Milton::Config::Install::cpan;

use strict;
use warnings;
use base 'Milton::Config::Install';

=head1 NAME

Milton::Config::Install::cpan - CPAN installer for Perl modules

=head1 DESCRIPTION

Installs Perl modules using the CPAN shell. Installs modules locally
for the current user only.

=cut

sub is_available {
  my ($self) = @_;
  # Check if cpan command exists
  my $cpan = `which cpan 2>/dev/null`;
  chomp $cpan;
  return $cpan && -x $cpan;
}

sub requires_sudo {
  return 0;  # CPAN installs locally
}

sub install {
  my ($self, $module) = @_;
  
  unless ($self->is_available()) {
    warn "CPAN is not available\n";
    return 0;
  }

  # Use cpan -i to install module
  return $self->execute('cpan', '-i', $module);
}

1;

