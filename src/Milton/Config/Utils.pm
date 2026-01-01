package Milton::Config::Utils;

use strict;
use warnings qw(all -uninitialized);
use FindBin qw($Bin);
use Path::Tiny;
use Carp qw(croak);

use Exporter qw(import);
our @EXPORT_OK = qw(getReflowProfiles getDeviceNames findDeviceFile getYamlParser standardSearchPath resolveConfigPath resolveWritableConfigPath);

use YAML::PP;
use YAML::PP::Schema::Include;
use Scalar::Util qw(reftype);

use Milton::Config qw(getYamlParser);
use Milton::Config::Path qw(resolve_file_path search_path);

=head1 NAME

Milton::Config::Utils - Utility functions for dealing with PSC configuration.

=head1 FUNCTIONS

=head2 getYamlParser

Return a YAML parser.

=cut

=head2 getReflowProfiles

  Returns a list of reflow profile names.

  Reflow profiles are assumed to be stored in YAML files that exist somewhere on the configuration
  file search path in the command/profile subdirectory. The list of names will be the basename of files
  that are found, with the .yaml file extension removed to make them comparible for use with the
  --profile command line option for the psc script.

=cut

sub getReflowProfiles {
  return findConfigFilesByPath('command/profile');
}

=head2 getDeviceNames

  Returns a list of device names.

  Device names are assumed to be stored in YAML files that exist somewhere on the configuration
  file search path in the device subdirectory. The list of names will be the basename of files
  that are found, with the .yaml file extension removed to make them comparible for use with the
  --device command line option for the psc script.

=cut

sub getDeviceNames {
  return findConfigFilesByPath('device');
}

sub findDeviceFile {
  my ($name) = @_;

  my @files = findConfigFilesByPath('device');
  foreach my $file (@files) {
    return $file->{value} if $file->{displayName} eq $name;
  }
  return $name;
}

=head2 findInterfaceConfigFiles

Returns 
=head2 resolveConfigPath($path, $optional)

Resolve the path to a configuration file.

This method tries to resolve the path to an existing configuration file using the standard configuration
search path. This method should be used when intending to read the configuration file that is found.

=over

=item $path

The path to the configuration file to resolve. Absolute paths are allowed and will eb returned unchanged.
Relative paths are resolved using the current configuration file search path.

=item $optional

Defaults to false.

If true, a file with the corresponding path does not need to exist and if the file is not found, relative
paths will be referenced to the first directory in the serach path, consistent with the behaviour of the
resolveWritableConfigPath function.

If false, an error will be thrown if the file is not found.

=item Return Value

The fully qualified path to the configuration file that will be read.

=back

=cut

sub resolveConfigPath {
  my ($path, $optional) = @_;
  my $fullpath = resolve_file_path($path, $optional);

  return $fullpath->stringify;
}

=head2 resolveWritableConfigPath($path)

Resolve the path to a configuration file that will be written by the current user.

The configuration file framework assumes that the first directory in the search path is the user's custom
configuration directory, so this function will always resolve relative paths into this directory, regardless
of whether the file already exists or not. This function should only be used in cases where the intention
is to write configuration out to the resolved path.

=over

=item $path

The relative path to which the configuration will be written. Absolute paths are not permitted here and will
result in an error.

=item Return Value

The fully qualified path to the configuration file that will be written.

=back

=cut

sub resolveWritableConfigPath {
  my ($path) = @_;
  my @search_path = search_path();

  if ($path =~ /^\//) {
    croak "Absolute paths are not permitted for writable configuration files: $path";
  }

  my $fullpath = path($search_path[0], $path);

  return $fullpath->stringify;
}

=head2 findConfigFilesByPath($path, $validate)

Find all configuration files in the search path that match the given path.

=over

=item $path

A relative path string to be searched for YAML files. The path may contain wildcards and other glob
pattern elements. The function will search all directories in the configuration search path 

=item $validate

=back

=cut

sub findConfigFilesByPath {
  my ($path, $validate) = @_;

  my @files = ();
  my @dirs = search_path();
  my $ypp = getYamlParser();
  my %seen;

  foreach my $dir (@dirs) {
    my @list = glob("$dir/$path/*.yaml");
    foreach my $file (@list) {
      my $relpath = substr($file, length($dir)+1);

      if ($seen{$relpath}) {
        next;
      }
      $seen{$relpath} = 1;

      my $doc = _readConfigMetadata($file);
      if (!defined $doc) {
        $doc = $ypp->load_file($file);
        next if reftype($doc) ne 'HASH';

        next if defined($validate) && !$validate->($doc);
      }

      my $name = $doc->{name};
      if (!$name) {
        $name = $file;
        $name =~ s/\.yaml$//;
        $name =~ s/^.*\///;
      }

      my $description = $doc->{description} || $name;

      push @files, { displayName => $name
                   , description => $description
                   , value => $relpath
                   };
    }
  }

  return sort { $a->{displayName} cmp $b->{displayName} } @files;
}

sub _readConfigMetadata {
  my ($path) = @_;
  my $re = qr/^#@ (\w+):\s*(.*)$/;

  my $fh = IO::File->new($path, 'r');
  my $line = $fh->getline;
  return if $line !~ /$re/;
  my $meta = { $1 => $2 };
  while ($line = $fh->getline && $line =~ /$re/) {
    $meta->{$1} = $2;
  }

  $fh->close;

  return $meta;
}

1;