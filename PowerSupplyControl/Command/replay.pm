package PowerSupplyControl::Command::replay;

use strict;
use warnings qw(all -uninitialized);
use Time::HiRes qw(time sleep);
use IO::File;
use Carp qw(croak);

use base qw(PowerSupplyControl::Command);

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);
  
  $self->{file} = shift @args;

  return $self;
}

sub preprocess {
  my ($self, $status) = @_;

  my $fh = $self->{fh} = IO::File->new($self->{file}, 'r') || croak "Failed to open file $self->{file}: $!";

  $self->info("Opened file $self->{file} for reading and playback");

  my $line = $fh->getline;
  chomp $line;
  my $headers = $self->{headers} = [ split /,/, $line ];
  $self->{logger}->consoleOutput('HEAD', "$line\n");

  my $start = time;

  while (my $line = $fh->getline) {
    chomp $line;
    my @values = split /,/, $line;
    my $status = {};
    @{$status}{@$headers} = @values;

    my $now = time - $start;
    my $howlong = $status->{now} - $now;
    if ($howlong > 0) {
      sleep $howlong;
    }
    $self->{logger}->consoleOutput('DATA', "$line\n");
  }

  $self->info("File playback complete.");

  return 1;
}

1;