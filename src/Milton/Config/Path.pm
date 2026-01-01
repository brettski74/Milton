package Milton::Config::Path;

use strict;
use warnings qw(all -uninitialized);
use FindBin qw($RealBin);
use Path::Tiny;
use Exporter qw(import);
use Carp qw(croak);

our @EXPORT_OK = qw(add_search_dir clear_search_path search_path resolve_file_path standard_search_path);

my @search_path;

=head1 DESCRIPTION

Functions for managing the search path for configuration files.

=head1 SYNOPSIS

  use Milton::Config::ConfigPath qw(add_search_path clear_search_path search_path resolve_file_path);

  clear_search_path();

  add_search_path('/path/to/config', '/other/path/to/config');

  my @search_path = search_path();
  print "Configuration directories:\n";
  foreach my $dir (@search_path) {
    print "$dir\n";
  }

  my $full_path = resolve_file_path('config.yaml');
  my $optional_full_path = resolve_file_path('optional.yaml', 1);

=head1 SUBROUTINES

=head2 add_search_dir(@dirs)

Add one or more directories to the search path for configuration files.

=over

=item @dirs

A list of directories to add to the search path.

=item Return Value

The list of directories in the search path after completion of the add.

=back

=cut

sub add_search_dir {
  my (@dirs) = @_;
  foreach my $dir (@dirs) {
    # Directory needs to be either an existing directory or non-existent.
    if ($dir && (-d $dir || !-e $dir)) {
      push @search_path, $dir;
    }
  }

  # Remove duplicates
  my %seen;
  for (my $i = 0; $i < @search_path; $i++) {
    if ($seen{$search_path[$i]}) {
      splice @search_path, $i, 1;
    } else {
      $seen{$search_path[$i]} = 1;
    }
  }

  return @search_path;
}

=head2 clear_search_path

Clear the search path for configuration files.

=cut

sub clear_search_path {
  @search_path = ();
}

=head2 search_path

Return the current list of directories that will be searched for configuration files.

=cut

sub search_path {
  return @search_path;
}

=head2 standard_search_path

Add the standard search path directories to the configuration search path.

The standard search path includes the following directories in the order listed below:

=over

The contents of the MILTON_CONFIG_PATH environment variable, if set. This can be a colon-separated list
of directories similar to environment variables like PATH and PERL5LIB.

$HOME/.config/milton

$MILTON_BASE/share/milton/config

=back

=cut

sub standard_search_path {
  add_search_dir(split(/:/, $ENV{MILTON_CONFIG_PATH})
               , "$ENV{HOME}/.config/milton"
               , "$ENV{MILTON_BASE}/share/milton/config"
               );
}

=head2 resolve_file_path($filename, $optional)

Resolve a filename to a full path, searching in the search path if needed.

=over

=item $filename

the filename to resolve. This may be either an absolute path, which will be returned unchanged, or a
relative path, which will be resolved into an absolute path by search the directories in the search
path. Directories will be searched in the order that they were added to the search path.

=item $optional

A boolean flag indicating whether the existence of the file is optional. If true, the existence of the
file is optional. If the file is not found, the function will return undef.
If false, the function will throw an exception if the file is not found.

=item Return Value

A Path::Tiny object representing the fully qualified path to the file matching the provided filename
if found, or undef if not found.

=back

=cut

sub resolve_file_path {
  my ($filename, $optional) = @_;
  my $path;

  if (!@search_path) {
    croak "No search path defined";
  }

  # Check if filename is relative
  if ($filename !~ /^\//) {
    $filename ||= 'psc.yaml';

    my ($found_path) = grep { path($_, $filename)->is_file } @search_path;

    if (!$found_path && $optional) {
      $found_path = $search_path[0];
    }

    croak "Config file '$filename' not found in search path: ". join(':', @search_path) unless $found_path;

    $path = path($found_path, $filename);
  } elsif (-f $filename || $optional) {
    $path = path($filename);
  } else {
    croak "Config file '$filename' not found";
  }

  return $path;
}

# Ensure that the MILTON_BASE environment variable is always set in milton scripts.
BEGIN {
  if (!defined $ENV{MILTON_BASE}) {
    $ENV{MILTON_BASE} = path($RealBin)->parent->stringify;
  }

  standard_search_path();
};

1;