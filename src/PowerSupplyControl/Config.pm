package PowerSupplyControl::Config;

use Carp qw(confess);

=head1 NAME

PowerSupplyControl::Config

=head1 DESCRIPTION

Load and hold hp static configuration with support for !include tags.

=cut

use strict;
use warnings qw(all -uninitialized);
use YAML::PP;
use YAML::PP::Schema::Include;
use Path::Tiny;
use Carp;
use Scalar::Util qw(reftype refaddr);
use Hash::Merge;
use Clone;
use Exporter qw(import);
our @EXPORT_OK = qw(getYamlParser);

my @search_path = ( '.' );

my %path_cache = ();

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

  my $self;

  if(defined $filename) {
    $self = _load_file($filename);
  } else {
    $self = {};
  }

  return bless $self, $class;
}

=head1 PRIVATE SUBROUTINES

=head2 _load_file($filename)

Load a YAML file and return the data as a reference.

=cut

sub _load_file {
  my ($filename) = @_;
  
  my $path = _resolve_file_path($filename);

  my $pathstring = $path->stringify;

  my $ypp = getYamlParser();

  my $depth = _path_push($pathstring);
  my $result = $ypp->load_file($pathstring);
  _path_pop($depth);

  $path_cache{refaddr($result)} = $pathstring;
  
  return $result;
}

my @path_stack = ();

sub _path_push {
  my ($path) = @_;
  my $rc = scalar @path_stack;

  push @path_stack, $path;

  return $rc;
}

sub _path_peek {
  return $path_stack[-1];
}

sub _resolve_child_filename {
  my ($filename) = @_;

  if ($filename =~ /^\//) {
    return $filename;
  }

  croak "Path stack is empty" unless scalar @path_stack;

  my $parent = path(_path_peek())->parent;
  if ($parent->is_dir) {
    my $child = $parent->child($filename);
    if ($child->is_file) {
      return $child->stringify;
    }
  }

  return _resolve_file_path($filename);
}

sub _path_pop {
  my ($depth) = @_;

  my $rc = pop @path_stack;
  my $actual = scalar @path_stack;

  if ($actual != $depth) {
    croak "Unbalanced path stack operations. Depth=$actual, Expected=$depth";
  }

  return $rc;
}

=head2 _resolve_file_path($filename)

Resolve a filename to a full path, searching in the search path if needed.

=cut

sub _resolve_file_path {
  my ($filename) = @_;
  my $path;

  # Check if filename is relative
  if ($filename !~ /^\//) {
    $filename ||= 'psc.yaml';

    my ($found_path) = grep { path($_, $filename)->is_file } @search_path;

    croak "Config file '$filename' not found in search path: ". join(':', @search_path) unless $found_path;

    $path = path($found_path, $filename);
  } else {
    $path = path($filename);
    croak "Config file '$filename' not found" unless $path->is_file;
  }

  return $path;
}

=head2 _create_node($node, $key)

Create a new node in the configuration at the specified path.

=cut

sub _create_node {
  my ($key) = @_;

  if ($key =~ /^\d+$/) {
    return [];
  }

  return {};
}

=head2 findKey(@keys)

Check if the specified path exists in the configuration.

=over

=item @keys

A list of keys to define the desired configuration path.

=item Return Value

Returns the value if it exists or undef if it does not.

Note that this means that a non-existent value is indistinguishable from a value that
exists but is set to undef, but I'm good with that.

=back

=cut

sub findKey {
  my ($self, @keys) = @_;
  my $node = $self;

  while (@keys && defined($node)) {
    my $key = shift @keys;

    if (reftype($node) eq 'HASH') {
      $node = $node->{$key};
    } elsif (reftype($node) eq 'ARRAY') {
      if ($key =~ /^-?\d+$/) {
        $node = $node->[$key];
      } else {
        return;
      }
    } else {
      return;
    }
  }

  return $node;
}

=head1 PRIVATE METHODS

=head2 _descend(@keys)

Descend to the specified path in the configuration and return a reference to the requested node.

=cut

sub _descend {
  my ($self, $create, @keys) = @_;

  my $node = $self;

  foreach my $key (@keys) {
    if (reftype($node) eq 'HASH') {
      if (!exists $node->{$key}) {
        if ($create) {
          $node->{$key} = _create_node($key);
        } else {
          croak 'Key '. join('->', @keys, $key) .' does not exist in configuration';
        }
      }
      $node = $node->{$key};
    } elsif (reftype($node) eq 'ARRAY') {
      croak 'Index '. join('->', @keys, $key) .' is an array, but key '. $key .' is not an integer' unless $key =~ /^\d+$/;

      if (!exists $node->[$key]) {
        if ($create) {
          $node->[$key] = _create_node($key);
        } else {
          croak 'Index '. join('->', @keys, $key) .' does not exist in configuration';
        }
      }
      $node = $node->[$key];
    } else {
      croak 'Key '. join('->', @keys) .' is scalar. Full path '. join('->', @keys, $key) .' does not exist in configuration';
    }
  }

  return $node;
}

=head1 CLASS METHODS

=head2 addSearchDir(@dirs)

Add one or more directories to the search path for configuration files.

=cut

sub addSearchDir {
  my ($class, @dirs) = @_;
  foreach my $dir (@dirs) {
    if ($dir && -d $dir) {
      push @search_path, $dir;
    }
  }
  return @search_path;
}

=head2 searchPath

Return the current list of directories that will be searched for configuration files.

=cut

sub searchPath {
  return @search_path;
}

=head2 configFileExists($filename)

Check if a configuration file exists in the search path.

=cut

sub configFileExists {
  my ($class, $filename) = @_;
  my $rc = undef;

  eval {
    my $path = _resolve_file_path($filename);
    $rc = $path->is_file;
  };

  return $rc if $rc;
  return;
}

sub findConfigFile {
  my ($class, $filename) = @_;

  eval {
    my $path = _resolve_file_path($filename);
    return $path->stringify if $path->is_file;
  };

  return;
}

=head1 INSTANCE METHODS

=head2 clone(@keys)

Clone one or more elements from the configuration, returning deep copies.

=over

=item @keys

A list of keys to clone from the configuration. If no keys are provided, clones the entire configuration.

=back

Returns a reference to a hash containing the cloned elements, or a single cloned element if only one key is provided.

=cut

sub clone {
  my ($self, @keys) = @_;

  my $node = $self->_descend(0, @keys);

  return Clone::clone($node);
}

=head2 merge($filename, @path)

Merge a YAML file into the configuration at the specified path.

=over

=item $filename

The name of the YAML file to merge.

=item @path

The path where the file contents should be merged.
An empty path will merge the contents of the file at the root level.

=back

=cut

sub merge {
  my ($self, $filename, @path) = @_;
  
  my $data = _load_file($filename);
  return $self if !defined $data;

  my $merge = Hash::Merge->new('LEFT_PRECEDENT');

  # Merging at the root level requires special handling
  if (!@path) {
    foreach my $key (keys %$data) {
      $self->{$key} = $merge->merge($data->{$key}, $self->{$key});
    }
    return $self;
  }

  my $child = pop @path;
  my $parent = $self->_descend(1, @path);

  if (reftype($parent) eq 'HASH') {
    if (exists $parent->{$child}) {
      $parent->{$child} = $merge->merge($data, $parent->{$child});
    } else {
      $parent->{$child} = $data;
    }
  } elsif (reftype($parent) eq 'ARRAY') {
    if (exists $parent->[$child]) {
      $parent->[$child] = $merge->merge($data, $parent->[$child]);
    } else {
      $parent->[$child] = $data;
    }
  } else {
    croak 'Path '. join('->', @path) .' is not a hash or array';
  }

  return $self;
}

=head2 path

Return the path from which this configuration was loaded.

=cut

sub getPath {
  my ($self, @keys) = @_;

  my $node = $self;
  if (@keys) {
    eval {
      $node = $self->_descend(0, @keys);
    };
    if ($@) {
      return;
    }
  }
  
  return $path_cache{refaddr($node)};
}

sub DESTROY {
  my ($self) = @_;
  delete $path_cache{refaddr($self)};
}

sub getYamlParser {
  my $include = YAML::PP::Schema::Include->new(
        loader => sub {
                    my ($yp, $filename) = @_;

                    my $full_path = _resolve_child_filename($filename);

                    #print "INFO: include loader loading filename: $filename, full_path: $full_path\n";

                    my $result = $yp->load_file($full_path);

                    if (reftype($result) eq 'HASH') {
                      $path_cache{refaddr($result)} = $filename;
                      bless $result, 'PowerSupplyControl::Config';
                    }

                    return $result;
                  }
      );

  my $ypp = YAML::PP->new(schema => ['+', $include]);
  $include->yp($ypp);

  return $ypp;
}

1;

