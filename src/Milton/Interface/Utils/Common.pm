package Milton::Interface::Utils::Common;

use strict;
use warnings qw(all -uninitialized);

use Path::Tiny;

use base 'Exporter';
our @EXPORT_OK = qw(device_compare port_exists);

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

sub port_exists {
  my ($port) = @_;

  if (-e $port) {
    if ($port =~ /^\/dev\/(ttyS[0-9]+)$/) {
      my $dev = $1;
      if (-d "/sys/class/tty/$dev/device/driver") {
        my $irq_file = path("/sys/class/tty/$dev/irq");
        my $irq = $irq_file->slurp;
        chomp $irq;
        if ($irq > 0) {
          return 1;
        }
      }
      # No driver directory or IRQ is not non-zero, so the port does not exist.
      return;
    }

    # Device file exists and not a standard 16550 UART, so assume it's good.
    return 1;
  }

  # Device file doesn't exist, so no bueno.
  return;
}

1;