#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);
use FindBin qw($Bin);
use Path::Tiny;

my $libdir;
BEGIN {
  my $libpath = path($Bin)->parent->child('lib')->child('perl5');
  $libdir = $libpath->stringify;
}

use lib $libdir;

use IO::File;

use Milton::Config;
use Milton::Config::Utils qw(resolveConfigPath resolveWritableConfigPath standardSearchPath);

standardSearchPath();

sub copy_file {
  my ($source, $target) = @_;

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
  my $source = resolveConfigPath($file, 1);
  my $target = resolveWritableConfigPath($file);

  if (-e $target) {
    if (-l $target) {
      # Make a copy of the source file to edit
      $source = readlink $target;
      unlink $target;
    }
  }

  if (! -e $target && -e $source) {
    copy_file($source, $target);
  }

  if (-e $target) {
    copy_file($target, "$target.$$");
  }

  EDIT: {
    system $editor, $target;

    if (-e $target) {
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
        unlink "$target.$$";
      }
    }
  }
}

