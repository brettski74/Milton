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

  my $resistance = $status->{voltage} / $status->{current};
  my $temperature = $self->{rt_estimator}->estimate($resistance);

  $status->{resistance} = $resistance;
  $status->{temperature} = $temperature;

  return $temperature;
}

1;
