package PowerSupplyControl::WebDataLogger;

use base 'PowerSupplyControl::DataLogger';

sub consoleProcess {
  my ($self, $type, $output) = @_;

  chomp $output;

  $output =~ s/\r?\n/\n$type: /g;

  return "$type: $output\n";
}

1;