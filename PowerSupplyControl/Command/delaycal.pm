package PowerSupplyControl::Command::delaycal;

use strict;
use warnings qw(all -uninitialized);
use YAML::PP qw(DumpFile);
use Scalar::Util qw(blessed);

use base qw(PowerSupplyControl::Command::reflow PowerSupplyControl::Command::calibrate);

#sub new {
#  my ($class, $config, $interface, $controller, @args) = @_;
#
#  my $self = $class->SUPER::new($config, $interface, $controller, @args);
#
#  return $self;
#}

sub postprocess {
  my ($self, $status, $history) = @_;

  my $samples = [];
  foreach my $sample (@$history) {
    if ($sample->{event} eq 'timerEvent' && exists $sample->{'device-temperature'}) {
      push @$samples, $sample;
    }
  }

  my ($tau, $tau_low) = $self->_calculateDelayFilter($status, $samples);

  my $output;
  if (PowerSupplyControl::Config->configFileExists($self->{config}->{filename})) {
    $output = PowerSupplyControl::Config->new($self->{config}->{filename});
  } else {
    $output = {};
  }

  $output->{'predict-time-constant'} = $tau;
  $output->{'predict-time-constant-low'} = $tau_low;

  my $path;
  if (blessed $output && $output->can('getPath')) {
    $path = $output->getPath;
  } else {
    $path = $self->{config}->{filename};
  }

  my $fh = $self->replaceFile($path);
  DumpFile($fh, $output);
  $fh->close;

  $self->_catFile($path);

  $self->beep;

  return 1;
}

1;