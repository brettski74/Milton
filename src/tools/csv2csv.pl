#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use IO::File;

my $filename = shift;

my $fh = IO::File->new($filename, 'r') or die "Failed to open $filename: $!";

my $line = $fh->getline;
chomp $line;
my @header = split /,/,$line;
print join(',', @ARGV) ."\n";

while ($line = $fh->getline) {
  chomp $line;
  my @fields = split /,/,$line;

  my %row;
  @row{@header} = @fields;

  my $sep = '';

  foreach my $key (@ARGV) {
    print "$sep$row{$key}";
    $sep = ',';
  }
  print "\n";
}

$fh->close;

exit 0;