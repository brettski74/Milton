package PowerSupplyControl::Config::Utils;

use strict;
use warnings qw(all -uninitialized);

use Exporter qw(import);
our @EXPORT_OK = qw(getReflowProfiles getDeviceNames getYamlParser);

use YAML::PP;
use YAML::PP::Schema::Include;
use Scalar::Util qw(reftype);

use PowerSupplyControl::Config qw(getYamlParser);

=head1 NAME

PowerSupplyControl::Config::Utils - Utility functions for dealing with PSC configuration.

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

sub findConfigFilesByPath {
  my ($path, $validate) = @_;

  my @files = ();
  my @dirs = PowerSupplyControl::Config::searchPath();
  my $ypp = getYamlParser();

  foreach my $dir (@dirs) {
    my @list = glob("$dir/$path/*.yaml");
    foreach my $file (@list) {
      my $doc = _readConfigMetadata($file);
      if (!defined $doc) {
        $doc = $ypp->load_file($file);
        next if reftype($doc) ne 'HASH';

        next if defined($validate) && !$validate->($doc);
      }

      my $relpath = substr($file, length($dir)+1);

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

  return @files;
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