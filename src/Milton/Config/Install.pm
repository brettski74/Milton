package Milton::Config::Install;

use strict;
use warnings;
use IO::Pipe;
use Carp qw(croak);

=head1 NAME

Milton::Config::Install - Base class for Perl module installers

=head1 DESCRIPTION

Base class for implementing different Perl module installation methods.
Subclasses should implement the install() and is_available() methods.

=cut

=head1 METHODS

=head2 new()

Constructor. Returns a new installer instance.

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  return $self;
}

=head2 execute(@command)

Execute a command and echo its output to the user.

=over

=item @command

Array of command and arguments to execute (e.g., ['cpanm', 'YAML::PP'])

=item Returns

Returns true on success (exit code 0), false on failure.

=back

=cut

sub execute {
  my ($self, @command) = @_;
  
  my $pipe = IO::Pipe->new;
  $pipe->reader(@command);  # Forks and execs command, makes pipe readable
  
  # Read and echo output
  $pipe->autoflush(1);
  while (my $line = <$pipe>) {
    print $line;  # Echo output to user
  }
  
  close $pipe;
  my $exit_code = $? >> 8;
  return $exit_code == 0;
}

=head2 set_install_path($path)

Set the path to the install directory for this installer.

=over

=item $path

The path to the install directory.

=back

=cut

sub set_install_path {
  return;
}

=head2 install($module)

Install a Perl module. Must be implemented by subclasses.

=over

=item $module

The module name to install (e.g., "YAML::PP")

=item Returns

Returns true on success, false on failure.

=back

=cut

sub install {
  my ($self, $module) = @_;
  croak "install() must be implemented by subclass";
}

=head2 is_available()

Check if this installation method is available on the system.
Must be implemented by subclasses.

=item Returns

Returns true if available, false otherwise.

=cut

sub is_available {
  my ($self) = @_;
  croak "is_available() must be implemented by subclass";
}

=head2 requires_sudo()

Check if this installation method requires sudo privileges.

=item Returns

Returns true if sudo is required, false otherwise.

=cut

sub requires_sudo {
  my ($self) = @_;
  return 0;  # Default to no sudo required
}

=head2 name()

Return the name of this installer.

=cut

sub name {
  my ($self) = @_;
  my $class = ref($self) || $self;
  $class =~ s/.*::Install::(.*)/$1/;
  return lc($class);
}

1;

