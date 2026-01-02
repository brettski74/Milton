package Milton::Interface::Utils::Common;

use strict;
use warnings qw(all -uninitialized);

use Path::Tiny;

use base 'Exporter';
our @EXPORT_OK = qw(device_compare);

sub device_compare {
  my ($a, $b) = @_;
  my ($atext, $anum) = $a =~ /^(.*?)([0-9]*)$/;
  my ($btext, $bnum) = $b =~ /^(.*?)([0-9]*)$/;
  my $result;

  if ($atext eq $btext) {
    $result = $anum <=> $bnum;
  } else {
    $result = $atext cmp $btext;
  }

  return $result;
}

1;