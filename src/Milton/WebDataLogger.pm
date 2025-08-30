package Milton::WebDataLogger;

use base 'Milton::DataLogger';

sub consoleProcess {
  my ($self, $type, $output) = @_;

  $| = 1;
  chomp $output;

  $output =~ s/\r?\n/\n$type: /g;

  return "$type: $output\n";
}

1;