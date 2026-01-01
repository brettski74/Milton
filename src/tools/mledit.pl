#!/usr/bin/perl

use Path::Tiny;
use FindBin qw($RealBin);
use lib path($RealBin)->sibling('lib', 'perl5')->stringify;
use Milton::Config::Path;

use strict;
use warnings qw(all -uninitialized);

use IO::File;

use Milton::Config;
use Milton::Config::Utils qw(resolveConfigPath resolveWritableConfigPath);
use Milton::Config::Path qw(standard_search_path);
use Milton::DataLogger qw($DEBUG_LEVEL_FILENAME);

standard_search_path();

sub copy_file {
  my ($source, $target) = @_;

  my $dir = path($target)->parent;
  $dir->mkpath if !$dir->is_dir;

  my $in = IO::File->new($source, 'r') || die "Failed to open $source for reading: $!";
  my $out = IO::File->new($target, 'w') || die "Failed to open $target for writing: $!";

  my $buffer;

  while (read $in, $buffer, 16384) {
    print $out $buffer;
  }

  $in->close;
  $out->close;

  return 1;
}

my $editor = $ENV{EDITOR} || 'vi';

# Default to psc.yaml if no files are specified
if (!@ARGV) {
  push @ARGV, 'psc.yaml';
}

foreach my $file (@ARGV) {
  # Allow use of "debug" as an abbreviation for the debug level configuration file.
  if ($file eq 'debug') {
    $file = $DEBUG_LEVEL_FILENAME;
  }

  my $source = resolveConfigPath($file, 1);
  my $target = resolveWritableConfigPath($file);

  if (-e $target) {
    if (-l $target) {
      # Make a copy of the source file to edit
      $source = readlink $target;
      unlink $target;
    }
  } else {
    my $dir = path($target)->parent;
    $dir->mkpath if !$dir->is_dir;
  }

  if (! -e $target && -e $source) {
    copy_file($source, $target);
  }

  if (-e $target) {
    copy_file($target, "$target.$$");
  }

  EDIT: {
    system $editor, $target;

    if (-e $target && $file =~ /\.yaml$/i && $file ne $DEBUG_LEVEL_FILENAME) {
      my $cfg;
      # Test file validity
      eval {
        $cfg = Milton::Config->new($file);
      };

      my $error;
      if ($@) {
        $error = $@;
      } elsif (!defined $cfg) {
        $error = "Unknown error";
      }

      if ($error) {
        print "Error validating $file: $error\n";
        my $choice;

        while ($choice ne 'K' && $choice ne 'R' && $choice ne 'E') {
          print "(K)eep changes, (R)evert changes or (E)dit again? ";
          $choice = <STDIN>;
          chomp $choice;
          $choice = uc(substr($choice, 0, 1));
        }
        if ($choice eq 'E') {
          redo EDIT;
        } elsif ($choice eq 'R') {
          copy_file("$target.$$", $target);
        }
      }

    }
  }

  unlink "$target.$$" if -e "$target.$$";
}

