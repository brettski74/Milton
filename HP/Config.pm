package HP::Config;

=head1 NAME

HP::Config

=head1 DESCRIPTION

Load and hold hp static configuration with support for !include tags.

=cut

use strict;
use warnings;
use YAML::PP;
use YAML::PP::Schema::Include;
use Path::Tiny;
use Carp;

my @search_path = ( '.' );
my %loaded_files;  # Track loaded files to detect circular references

=head1 CONSTRUCTOR

=head2 new($filename)

Create a new config object from the specified file.

=over

=item $filename

The name of the file containing the configuration to be loaded. If the file contains any path
information, then the file will be loaded using the path given. This may be either an absolute
or relative path. If the filename contains no path information, then this constructor will
search several well-known paths for the matching filename and load the first matching file it
finds. If $filename is undefined, then it will be defaulted to hp.yaml.

=back

=cut

sub new {
  my ($class, $filename) = @_;
  
  # Reset loaded files tracking for new config load
  %loaded_files = ();

  my $include = YAML::PP::Schema::Include->new; 
  my $ypp = YAML::PP->new(schema => ['+', $include]);
  $include->yp($ypp);
  
  my $path = _resolve_file_path($filename);
  
  # Load YAML and bless into object
  my $self = $ypp->load_file($path->stringify);
  croak "Config file '$path' did not return a hash" unless ref($self) eq 'HASH';

  return bless $self, $class;
}

=head1 PRIVATE METHODS

=head2 _resolve_file_path($filename)

Resolve a filename to a full path, searching in the search path if needed.

=cut

sub _resolve_file_path {
  my ($filename) = @_;
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
  
  return $path;
}

=head2 _handle_include($ypp, $node)

Handle !include tags by loading the specified file and returning its contents.

=cut

sub _handle_include {
  my ($ypp, $node) = @_;
  
  my $include_file = $node->value;
  
  # Resolve the include file path relative to the current file being loaded
  my $current_file = $ypp->current_file;
  my $include_path;
  
  if ($include_file =~ /^\//) {
    # Absolute path
    $include_path = path($include_file);
  } else {
    # Relative path - resolve relative to current file's directory
    my $current_dir = path($current_file)->parent;
    $include_path = $current_dir->child($include_file);
  }
  
  # Check for circular references
  my $canonical_path = $include_path->canonpath;
  if (exists $loaded_files{$canonical_path}) {
    croak "Error: Circular reference detected in include file: $include_file";
  }
  
  # Mark this file as being loaded
  $loaded_files{$canonical_path} = 1;
  
  # Check if file exists
  unless ($include_path->is_file) {
    croak "Error: Failed to load include file: $include_file";
  }
  
  # Load the included file
  my $included_ypp = YAML::PP->new;
  $included_ypp->add_tag_handler('!include', \&_handle_include);
  
  my $included_data = $included_ypp->load_file($include_path->stringify);
  
  # Remove the file from loaded_files tracking after successful load
  delete $loaded_files{$canonical_path};
  
  return $included_data;
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

