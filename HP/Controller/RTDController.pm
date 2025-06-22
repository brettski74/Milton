package HP::Controller::RTDController;

use strict;
use HP::PiecewiseLinear;
use base qw(HP::Controller);

=head1 NAME

HP::Controller::RTDController - base class for controllers that use the heating element as an RTD to estimate temperature.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  # Convert the temperature/resistance values into a piecewise linear estimator
  my $est = HP::PiecewiseLinear->new;
  foreach my $measurement (@{$self->{temperatures}}) {
    $est->addPoint($measurement->{resistance}, $measurement->{temperature});
  }
  $self->{rt_estimator} = $est;

  return $self;
}

=head2 getTemperature($status)

Get the current temperature of the hotplate based on it's latest measured resistance.

=over

=item $status

The current status of the hotplate as provided by the framework. It needs to contain the current voltage and current measurements.
From this, the resistance of the heating element will be calculated. This is then used to estimate the current temperature of the
hotplate.

On return, the calculatd resistance and temperature values will be placed in the status hash and may be used elsewhere.

=item Return Value

Returns the estimated temperature of the hotplate in degrees celsius.

=back

=cut

sub getTemperature {
  my ($self, $status) = @_;
  my $est = $self->{rt_estimator};

  my $resistance = $status->{voltage} / $status->{current};

  # If the estimator is empty, give it some sane defaults assuming a copper heating element
  if ($est->length() == 0) {
    my $ambient = $self->{ambient} || 20.0;
    # A 1 ohm copper resistor at 20C will measure about 1.7 ohms at 200C.
    $est->addPoint($resistance, $ambient);
  }
  
  # If the estimator has only one point, add a second point to make it a linear estimator
  if ($est->length() == 1) {
    my $r0 = $est->[0]->[0];
    my $t0 = $est->[0]->[1];
    my $r1 = $r0 * 1.7;
    my $t1 = $t0 + 180.0;
    $est->addPoint($r1, $t1);
  }

  my $temperature = $est->estimate($resistance);

  $status->{resistance} = $resistance;
  $status->{temperature} = $temperature;

  return $temperature;
}

1;
