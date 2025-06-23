package HP::Command::calibrate;

use strict;
use warnings;

use base qw(HP::Command);
use Scalar::Util qw(looks_like_number);
use Readonly;
use Carp;

Readonly my %ALLOYS => ( In97Ag3 => 143
                       , In52Sn48 => 118
                       , In663Bi337 => 72
                       , Sn63Pb37 => 183
                       , Sn965Ag35 => 221
                       , Sn62Pb36Ag2 => 179
                       , Bi58Sn42 => 138
                       , Sn993Cu07 => 227
                       , Indium => 157
                       , Tin => 232
                       );

=head1 NAME

HP::Command::calibrate - Calibrate the hotplate

=head1 SYNOPSIS

  my $self = HP::Command->new($config);

  return $self;
}

=head1 DESCRIPTION

Run a calibration cycle to determine the following details for the hotplate:

=over

=item Resistance to temperature mapping

In theory, we can determine the resistance of the hotplace at different temperatures based on the resistance measured at
one temperature and the applying the formula for resistance based on the temperature coefficient of the material -
presumably copper. In practice, a piecewise linear approximation seems to produce better results, so you can specify
several target temperatures that will have corresponding resistance recorded. During the calibration cycle, you will
need to hit the spacebar as each calibration temperature is reached. The resistance measured at that time will then be
recorded as the resistance corresponding to that temperature.

=item Thermal resistance to ambient

For feed-forward control, we need an operating thermal model of the hotplate. The model used has two parameters. The
first of those is the thermal resistance of the hotplate to the ambient environment. This relates the rate at which heat
is lost to the surrounding environment in proportion to the temperature difference between the hotplate and the ambient
temperature. This will be estimated by applying a constant power level to the hotplate and observing the steady state
temperature that the hoplate reaches from both below and above the steady state temperature.

=item Heat capacity

This is the second parameter needed for the thermal model. It specifies the amount of energy required to raise the
temperature of the hotplate by one degree Celsius/Kelvin. Once we have the thermal resistance, we can fit an exponential
curve to the time versus temperature data and calculate the heat capacity from the time constant of the system.

=back

=head2 Calibration Cycle

The calibration cycle will progress through the following stages:

=over

=item Constant Power Warm Up

A constant power level is applied to the hotplate and the temperature difference between successive samples is monitored
and recorded. The temperature deltas are passed through an IIR low pass filter and when the filtered result falls below
a suitable threshold, the hotplate is assumed to be very close to the steady state temperature for the given power level.
Based on that, an initial estimate of the thermal resistance and heat capacity are calculated and used in the next stage
to effect control of the hotplate. Since we don't have a resistance to temperature mapping at this point, we use an
approximation based on the cold resistance of the hotplate and the temperature coefficient of copper.

=item Slow Temperature Ramp

Once a steady state temperature is reached in the previous stage, the hotplate is then heated at a constant slow rate
until the maximum calibration temperature is reached. At this point, we can build a complete resistance to temperature
mapping.

=item Short Hold

The temperature increase is continued until the maximum calibration temperature is exceeded by a small safety margin and
and then held there for a short period of time to ensure the hotplate is at a steady state again.

=item Cool Down

The initial calibration power is re-applied to the hotplate and it is allowed to cool back down to a steady state. The
same steady state condition using an IIR low pass filter is used to determine steady state.

=back

Once all stages have been completed, the entire history of measurements are updated with accurate temperature values
via our complete resistance to temperature mapping. We then re-calculate the thermal model parameters using both the
warm up and cool down curves and average the results to produce a final set of parameters.

=head1 CONFIGURATION PARAMETERS

The following configuration parameters are understood by this command and should be specified in the commands->calibrate
section of the configuration file. Some of them can also be provided on the command line.

=over

=item temperatures

A list of temperatures to calibrate the hotplate for the resistance to temperature mapping. These can be specified as
either a temperature in degrees Celsius or a known alloy name. There are two suggested ways to calibrate the resistance
to temperature mapping.

=over

=item Digital Thermometer

If you have a digital thermometer of some sort you can use it to measure the temperature of the hotplate as it is heated
during the calibration cycle. This could be a kitchen thermometer or a thermocouple attached to a multimeter or any other
kind of device that can accurately record the temperature. Good thermal coupling to the hotplate is important to ensure
accurate and timelin temperature measurements. The use of kaptan tape or thermal paste may be helpful in ensuring this,
provided you're willing to get such materials onto your thermometer probe. Thermal paste may not be a great option if you
plan to use the thermometer in the kitchen afterwards!

=item Calibration Alloys

If you have several different solder alloys available, you can use them to calibrate the hotplate. Ideally, these should
be eutectic solder alloys so that they have a well defined melting point. You simply cut a short piece of solder wire of
each alloy - perhaps 3-4 mm long. You then place these near the centre of the hotplate and wait for them to melt. You want
pieces that are about 2-3 times as long as they are wide. When they melt, surface tension will cause them to form a sphere
almost instantly, which is easy to observe. If the wire is too short, the transition from cylinder to sphere may be had to
spot. Similarly, if the wire is too long, the transition to a more ball-shaped glob of liquid may be slower.

=back

=item initial-power

The initial power applied to the hotplate during preprocessing to ensure that resistance can be measured in the first polling
once the main event loop starts. This defaults to 10 watts.

=item power

The calibration power applied to the hotplate during the constant power stages of the calibration cycle. If not explicitly
specified, it can be defaulted to a reasonable value based on an estimate of thermal resistance using the mechanical details
of your hotplate assembly and the calibration temperatures you plan to use. The goal is to aim for a steady state temperature
where the temperature rise above ambient is about 90% of the way to the first calibration temperature. In the absence of
mechanical details of the hotplate assembly, a thermal resistance of 2.4K/W will be assumed.

=item temperature-rate

The rate in Celsius/Kelvin per second at which the hotplate is heated during the slow temperature ramp. This detauls to
0.5K/s.

=item steady-state-alpha

The alpha value for the IIR low pass filter used to determine steady state temperature. This defaults to 0.1. Values closer
to zero will result in a slower response to temperature changes and a longer period of time for the calibration cycle to
settle and move on to the next stage but will be more accurate in determining steady state.

=item steady-state-threshold

The threshold for the IIR low pass filter used to determine steady state temperature. Since we don't yet have an up-to-date
resistance to temperature mapping, steady state is determined by looking at resistance deltas as a proxy for temperature
deltas. Therefore, the threshold is essentially a resistance value and will be defaulted to 10% of the cold temperature
resistance of the hotplate.

=item steady-state-samples

The number of samples to use to determine steady state temperature. There must be at least 10 consecutive samples that meet
the steady state criteria before steady state is considered to have been reached. This defaults to 10.

=item steady-state-reset

The threshold above which we stop counting positive steady state samples. This defaults to 1.5 times the steady state
threshold.

=back

=head1 METHODS

=head2 defaults

Return a hash of default configuration values for this command.

=cut

sub defaults {
  return { 'initial-power' => 10.0
         , 'temperature-rate' => 0.5
         , 'steady-state-alpha' => 0.1
         , 'steady-state-samples' => 10
         };
}

=head2 options

Return a hash of options for Getopt::Long parsing of the command line arguments.

=cut

sub options {
  return ( 'reset' );
}

=head2 initialize

Initialize the calibrate command.

=cut

sub initialize {
  my ($self) = @_;

  if ($self->{reset}) {
    $self->{controller}->resetCalibration;
  }

  my $temps = $self->{temperatures};
  foreach my $temp (@$temps) {
    if (!looks_like_number($temp)) {
      if (exists $ALLOYS{$temp}) {
        $temp = $ALLOYS{$temp};
      } else {
        croak "Unknown calibration temperature in configuration: $temp";
      }
    }
  }

  # Ensure that the temperatures are in ascending order.
  @$temps = sort { $a <=> $b } @$temps;

  return $self;
}

=head2 preprocess

Initialize the calibrate command.

This method is called during object creation.

=cut

sub preprocess {
  my ($self) = @_;

  # Ensure that we have some power flowing into the hotplate so that resistance can be measured.
  $self->{interface}->setPower($self->{config}->{initial_power});
  $self->{stage} = 'warmUp';

  return $self;
}

=head2 timerEvent($status)

Handle a timer event.

=over

=item $status

A hash reference containing the current status of the hotplate.

=back

=cut

sub timerEvent {
  my ($self, $status) = @_;

  my $stage = '_'. $self->{stage};
  return $self->$stage($status);
}

=head2 _warmUp($status)

Handle the warm up stage of the calibration cycle.

=cut

sub _warmUp {
  my ($self, $status) = @_;

  $self->{interface}->setPower($self->{config}->{'initial-power'});

  if ($self->{'log-columns'}) {
    print join(',', @{$status}{@{$self->{'log-columns'}}}), "\n";
  }

  return $self;
}

1;