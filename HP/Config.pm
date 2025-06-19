package HP::Config;

=head1 NAME

HP::Config

=head1 DESCRIPTION

Load and hold hp static configuration.

=cut

use strict;
use warnings;
use YAML::PP;
use Path::Tiny;
use Carp;

my @search_path = ( '.' );

=head1 CONSTRUCTOR

=head2 new($filename)

Create a new config object from the specified file.

=over

=item $filename

The name of the file containing the configuration to be loaded. If the file contains any path
information, then the file will be loaded using the path given. This may be eithe an absolute
or relative path. If the filename contains no path information, then this constructor will
search several well-known paths for the matching filename and load the first matching file it
finds. If $filename is undefined, then it will be defaulted to hp.yaml.

=back

=cut

sub new {
  my ($class, $filename) = @_;
  my $ypp = YAML::PP->new;
  my $path;
    
  # Check if filename is unqualified
  if ($filename !~ /\//) {
    $filename ||= 'hp.yaml';

    my ($found_path) = grep { path($_, $filename)->is_file } @search_path;

    croak "Config file '$filename' not found in search path: ". join(':', @search_path) unless $found_path;

    $path = path($found_path, $filename);
  } else {
    $path = path($filename);
    croak "Config file '$filename' not found" unless $path->is_file;
  }

  # Load YAML and bless into object
  my $self = $ypp->load_file($path->stringify);
  croak "Config file '$path' did not return a hash" unless ref($self) eq 'HASH';

  return bless $self, $class;
}

=head1 METHODS

=head1 SUBROUTINES

=head2 addSearchDir(@dirs)

Add one or more directories to the search path for configuration files.

=cut

sub addSearchDir {
  push @search_path, @_;
}

=head2 searchPath

Return the current list of directories that will be searched for configuration files.

=cut

sub searchPath {
  return @search_path;
}

1;

