#!/usr/bin/perl

use Path::Tiny;
use FindBin qw($RealBin);
use lib path($RealBin)->sibling('lib', 'perl5')->stringify;
use Milton::Config::Path qw(search_path);
use Milton::DataLogger;

use Milton::Interface::Utils::SCPIScanner;

use strict;
use warnings qw(all -uninitialized);

my $logger = Milton::DataLogger->new({ tee => 1, enable => 1 });

my $scanner = Milton::Interface::Utils::SCPIScanner->new(logger => $logger);

my @found = $scanner->scanSCPISerialDevices;

push @found, $scanner->scanSCPIUSBTMCDevices;

print "Which power supply would you like to use? (1-", scalar(@found), "): \n\n";
foreach my $i (0..$#found) {
  printf "  %d) %s (%s)\n", $i + 1, $found[$i]->{displayName}, $found[$i]->{device};
}

print "Done.\n";

