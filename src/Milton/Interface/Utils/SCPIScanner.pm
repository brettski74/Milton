package Milton::Interface::Utils::SCPIScanner;

use strict;
use warnings qw(all -uninitialized);
use Readonly;

use base 'Exporter';
our @EXPORT_OK = qw(scan_scpi_devices);

Readonly my @BAUD_RATE => ( 115200, 9600, 19200, 38400, 57600, 4800 );

sub scan_scpi_devices {
  my @ports = glob('/dev/tty{S,USB,AMA}[0-9]*');

  foreach my $port (@ports) {
    next if !port_exists($port);

    print "Scanning port $port\n";

    foreach my $baud (@BAUD_RATE) {
      print "  Trying baud rate $baud\n";

      my $config = { baudrate => $baud, port => $port };
      my $interface;
      
      $interface = Milton::Interface::SCPISingle->new($config);
      if ($interface) {
        print "  Connected to device at $port at $baud baud\n";
      } else {
        print "  Failed to connect to device at $port at $baud baud\n";
      }

      # For now we're only going to try 8N1 serial connections until such time as we find a device that requires something else.


    }
  }
}


1;