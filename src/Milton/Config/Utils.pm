package Milton::Config::Utils;

use strict;
use warnings qw(all -uninitialized);
use FindBin qw($Bin);
use Path::Tiny;
use Carp qw(croak);

use Exporter qw(import);
our @EXPORT_OK = qw(find_config_files_by_path find_reflow_profiles get_device_names find_device_file get_yaml_parser);

use YAML::PP;
use YAML::PP::Schema::Include;
use Scalar::Util qw(reftype);

use Milton::Config;
use Milton::Config::Path qw(resolve_file_path search_path);

=head1 NAME

Milton::Config::Utils - Utility functions for dealing with PSC configuration.

=head1 FUNCTIONS

=head2 get_yaml_parser

Return a YAML parser.

=cut

=head2 find_reflow_profiles

  Returns a list of reflow profile names.

  Reflow profiles are assumed to be stored in YAML files that exist somewhere on the configuration
  file search path in the command/profile subdirectory. The list of names will be the basename of files
  that are found, with the .yaml file extension removed to make them comparible for use with the
  --profile command line option for the psc script.

=cut

sub find_reflow_profiles {
  return find_config_files_by_path('command/profile');
}

=head2 get_device_names

  Returns a list of device names.

  Device names are assumed to be stored in YAML files that exist somewhere on the configuration
  file search path in the device subdirectory. The list of names will be the basename of files
  that are found, with the .yaml file extension removed to make them comparible for use with the
  --device command line option for the psc script.

=cut

sub get_device_names {
  return find_config_files_by_path('device');
}

sub find_device_file {
  my ($name) = @_;

  my @files = find_config_files_by_path('device');
  foreach my $file (@files) {
    return $file->{value} if $file->{displayName} eq $name;
  }
  return $name;
}

=head2 find_config_files_by_path($path, $validate)

Find all configuration files in the search path that match the given path.

=over

=item $path

A relative path string to be searched for YAML files. The path may contain wildcards and other glob
pattern elements. The function will search all directories in the configuration search path 

=item $validate

A code reference that will be called with the loaded configuration document as its argument. If the
function call returns true, the file will be included in the returned list, otherwise it will be
excluded from the list. This can be used to perform arbitrary filtering of the resulting list. For
example, you could use this to only include files that include a defined value for a given key.

=back

=cut

# Note: This function is dependent on the Milton::Config module and therefore should not be moved to
# Milton::Config::Path.

sub find_config_files_by_path {
  my ($path, $validate) = @_;

  my @files = ();
  my @dirs = search_path();
  my %seen;

  foreach my $dir (@dirs) {
    my @list = glob("$dir/$path/*.yaml");
    foreach my $file (@list) {
      my $relpath = substr($file, length($dir)+1);

      if ($seen{$relpath}) {
        next;
      }
      $seen{$relpath} = 1;

      my $doc = _read_config_metadata($file);
      my $record = { value => $relpath};

      if (defined $doc) {
        $record->{name} = $doc->{name};
        $record->{displayName} = $doc->{displayName} || $doc->{name};
        $record->{description} = $doc->{description} || $record->{displayName};
      }

      if (!defined $doc || $validate) {
        $doc = Milton::Config->new($relpath);
        $record->{document} = $doc;
        next if reftype($doc) ne 'HASH';

        next if defined($validate) && !$validate->($doc);
        
        $record->{name} //= $doc->{name};
        $record->{displayName} //= $doc->{name};
        $record->{description} //= $doc->{description};
      }

      if (!$record->{displayName}) {
        my $name = $file;
        $name =~ s/\.yaml$//;
        $name =~ s/^.*\///;
        $record->{displayName} = $name;
      }

      $record->{name} //= $record->{displayName};
      $record->{description} //= $record->{displayName};

      push @files, $record;
    }
  }

  return sort { $a->{displayName} cmp $b->{displayName} } @files;
}

sub _read_config_metadata {
  my ($path) = @_;
  my $re = qr/^#@ (\w+):\s*(.*)$/;

  my $fh = IO::File->new($path, 'r');
  my $line = $fh->getline;
  return if $line !~ /$re/;
  my $meta = { $1 => $2 };
  while ($line = $fh->getline) {
    if ($line =~ /$re/) {
      $meta->{$1} = $2;
    } else {
      last;
    }
  }

  $fh->close;

  return $meta;
}

1;