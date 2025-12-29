package Milton::Command::ManualTuningCommand;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Command);

sub processSamples {
  my ($self, $samples) = @_;

  my $rmean = 0;
  my $tmean = 0;
  my $pmean = 0;
  my $rcount = 0;
  my $tcount = 0;
  my $pcount = 0;

  foreach my $sample (@$samples) {
    if (exists $sample->{resistance}) {
      $rmean += $sample->{resistance};
      $rcount++;
    }
    if (exists $sample->{'device-temperature'}) {
      $tmean += $sample->{'device-temperature'};
      $tcount++;
    }
    if (exists $sample->{power}) {
      $pmean += $sample->{power};
      $pcount++;
    }
  }

  $rmean /= $rcount;
  $tmean /= $tcount;
  $pmean /= $pcount;
  $self->info("resistance: $rmean, temperature: $tmean, power: $pmean, counts: [ $rcount, $tcount, $pcount ]");

  @$samples = ();
  return;
}

sub timerEvent {
  my ($self, $status) = @_;

  my $samples = $self->{rsamples};
  if (!$samples) {
    $samples = [];
    $self->{rsamples} = $samples;
  }

  push @$samples, $status;

  my $result = $self->processTimerEvent($status);

  if (@$samples >= 10) {
    $self->processSamples($samples);
  }

  return $result;
}

sub processTimerEvent {
  my ($self, $status) = @_;

  return $status;
}

1;