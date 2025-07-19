package PowerSupplyControl::Command::calibrate;

use strict;
use warnings qw(all -uninitialized);


use base qw(PowerSupplyControl::Command::CalibrationCommand);
use Math::Round qw(round);
use List::Util qw(min max);
use Readonly;
use Carp qw(croak);
use Time::HiRes qw(sleep);

use PowerSupplyControl::Math::FirstOrderStepEstimator;
use PowerSupplyControl::Math::PiecewiseLinear;
use PowerSupplyControl::Math::SimpleLinearRegression;
use PowerSupplyControl::Math::Util qw(mean minimum maximum minimumSearch);

=head1 NAME

PowerSupplyControl::Command::calibrate - Calibrate the hotplate

=head1 SYNOPSIS

  my $self = PowerSupplyControl::Command->new($config);

  return $self;
}

=head1 DESCRIPTION

Run a calibration cycle to fully characterize the thermal behaviour of the hotplate assembly. This will produce the following
assets:

=over

=item Resistance to temperature mapping

=item Temperature to Thermal resistance mapping

=item Temperature to Heat capacity mapping

=over

=head1 DO YOU REALLY NEED TO CALIBRATE?

If you have a PCB hotplate with a copper foil heating element, you probably don't need to calibrate. A quick linear
approximation of the hotplate resistance based on a room temperature resistance measurement and the known properties
of annealed copper should be sufficient. Use the BangBang controller - it needs virtually no calibration. This is more
than sufficient for most applications.

Where you may need/want to calibrate:

=over

=item You have a hotplate with a heating element not made of copper

Maybe you're using some hotplate made from some exotic material fashioned by pixies in a dark forest in a far away land.
Cool! If you don't know the material properties, calibration could be the way to let the software know just how to drive
your fancy hotplate. Note that there is also a much quicker calibration command - the ramp calibration command. It's
aimed at doing a quick one-pass calibration over the range of temperatures you care about. It only produces a resistance
to temperature mapping, not a full characterization of the thermal behaviour, but that's still good enough for BangBang
control to work.

=item You're convinced that being 3 degrees off in temperature is going to cause premature failure of your components

Realistically, this is probably not a thing. Reflow soldering is a far gentler process on components than other options
like hand soldering or usnig a hot-air station. Soldering temperatures are more tightly controlled and generally lower
than in other soldering processes and the thermal gradients are much smaller due to the even heating across the entire
board being reflowed rather than spot heating that may occur in other processes. Realistically, a good calibration
might take your hotplate's accuracy from maybe +/- 8 degrees celsius to maybe +/- 3 degrees. If tight controls are
really that important, maybe a DIY solution isn't the right answer for your application.

=item You're worried about the thermal stresses of Bang-Bang control

If this is a thing, it's likely a pretty minor thing and likely most impactful for the hotplate PCB itself. The thermal
time constant of a typical reflow hotplate assembly is quite long - probably on the order of 40-60 seconds or even more.
That acts like a really slow responding, low-pass filter on the heat output of the hotplate. Your loads are unlikely to 
see large thermal gradients due to the on-off cycling of Bang-Bang control. But if you're hoping to show off smoother
graphs and hope that your hotplate PCB lasts 10% longer, maybe a calibration and using FeedForward+PID control will help
you sleep better at night.

=item Curiosity about thermal systems

This is probably the most likely reason to do this. I wrote these calibration routines and the various control schemes
partly as a learning exercise and partly because I really didn't know how well these things would work. Playing around
with calibration and looking at graphs of the data I captured exposed a lot of interesting nuances about how systems
like this hotplate behave, how they deviate from idealized first-order models and how the material properties change
with temperature. A good calibration will show you effects of things like the glass transition temperature of the resin
in your PCB affects effective heat capacity and the energy required to heat it up. You can see how thermal resistance
changes with temperature as the heat spreads out into more and more of the assembly at higher temperatures, effectively
increasing the area through which heat can be lost and lowering the effective thermal resistance. You can even see
transient heat effects and how heat flows from the heating element and into the rest of the assembly. This can be a
fun exercise, but in reality, it's probably not helping you reflow PCBs any better.

=back

=head1 CALIBRATION ASSETS

=head2 Resistance to temperature mapping

In theory, we can determine the resistance of the hotplace at different temperatures based on the resistance measured at
one temperature and the applying the formula for resistance based on the temperature coefficient of the material -
presumably copper. In practice, this isn't quite perfect. A piecewise linear approximation of the resistance to temperature
relationship can help adjust for thermal lag and offset effects that may lead to small differences in the temperature
measured at the heating element versus at the surface of the hotplate. Or maybe it just gives you peace of mind knowing
that your hotplate's output has been calibrated against a somewhat known standard rather than making a rough guess
based on that physics textbook you found in your Dad's attic in 1973.

=head2 Thermal resistance to ambient

For feed-forward control, you need an operating thermal model of the hotplate to predict how the hoplate will react
to various power inputs. We use a first order thermal model with just two parameteters. The first is the thermal
resistance of the hotplate to the ambient environment. This relates the rate at which the hotplate assembly loses
heat to the surrounding environment. This increases with increasing temperature. Ideally, this would be a simple
linear relationship. In practice, while heat flow is a linear process, our first-order thermal model only loosely
matches reality. A more complicated model which beter matches reality creates more problems than it solves, so
instead characterizing the thermal resistance as a value which varies with temperature is a simpler solution. We
characterize the effective, first-order thermal resistance of the hotplate assembly as a function of temperature.

For PID control, we don't necessarily need a working thermal model. We just need proportional, integral and differential
gains that produce a good response to the temperature error. There are various ways to tune these gain parameters
for good performance, but one way is based on knowing the thermal model parameters. We use thermal resistance and
heat capacity to select PID parameters that should work well for a given hotplate assembly. Additionally, because
we have characterized these properties as functions of temperature, we can apply variable PID gains at different
temperature to better match the varying thermal behaviour of the hotplate assembly as it heats up and cools down.

=head2 Heat capacity

This is the second parameter needed for the thermal model. It specifies the amount of energy required to raise the
temperature of the hotplate by one degree Celsius/Kelvin. Ideally, this would also be a constant value, but like
thermal resistance, the effective, first-order heat capacity of teh hotplate assembly varies with temperature. There
are two main reasons why. Firstly, as the assembly heats up, more heat starts to flow further into the various componets
of your assembly. As this happens, it has an effect similar to adding more material that you need to heat up. This is
the main component responible for the gentle gradient you see in the heat capacity mapping at lower temperatures.
As you start getting up above 120-140 celsius, you'll likely see a much steeper gradient appear. This is likely due
to the glass transition temperature of the resin in your PCB. As you approach and pass the glass transition temperature
some of the resin starts to undergo a phase change as it starts to soften. Don't worry about this too much. Most FR4
material used in PCBs is still pretty rigid up to and beyond reflow temperatures. But this phase change is happening
and requires energy, so it starts to take more energy for every degree of temperature rise while this is going on.
This shows up as a steeper gradient in your temperature to heat capacity mapping.

=back

=head2 Calibration Cycle

The calibration cycle operates in a series of steps. It will apply constant power inputs to the hotplate at
a varety of different power levels. It tries to approach the equilibrium point associated with each of these
power levels from both directions - rising and falling. By doing this, we get the data we need to get very good
estimates of the equilibrium temperature for each power level. By using an external temperature sensor such as
a digital multimeter with a thermocouple or a digital kitchen thermometer or an arduino-based thermistor rig,
we can note the mearured temperatures as we approach these equilbrium points. That provides our resistance to
temperature mapping, which then allows us to put accurate temperatures against those equilibrium points and
calculate thermal resistance. Finally, we can fit curves to the remaining data and use that to determine
the effective heat capacity at the various temperatures

The following parameters can be configured to control and fine-tune the calibration cycle:

=over

=item power-step

A value in watts that specifies the difference between successive power levels to be applied during the calibration
cycle. Each power level used during the calibration will be an integer multiple of this value. The default value
is 8 watts.

=item step-duration

The amount of time in seconds to spend in each rising or falling step of the calibration cycle. It is strongly
advised to ensure that thsi number is an integer multiple of your sampling interval.The default value
is 180 seconds. For each power level, there will be two steps - one rising and one falling. So for a 6-point
calibration cycle, you will spend 12 times this value running the calibration cycle.

=item maximum-temperature

This is what will ultimately limit the number of steps in the calibration cycle. The calibration will continue
running increasingly higher power steps until a step reaches this apparent temperature. The default value is 220
celsius. This defaults to 220 celsius, which is a little below the trigger point of a SnSb based thermal fuse,
which trips at approximately 235 celsius.

=item discard-samples

The number of samples that are discarded from the beginning of each step for curve fitting analysis. When we
apply a significant step, the effect is most immediately seen in the temperature of the heating element, which
has very low thermal inertia and there is a lag in the effects becoming visible in the rest of the hotplate
assembly. this can lead to weird transient effects shortly after the step change is applied. Discarding the
first few samples helps to get sample data that more closely fits the expected first-order step response and
should produce more accurate resutls from the regression analysis. The default value is 4, which corresponds
to 6 seconds of discarded data for a typical 1.5 second sampling interval. If you use a different sampling
interval, you may want to adjust this parameter accordingly.

=over

=head1 COMMAND LINE OPTIONS

The command recognizes the following command-line options:

=over

=item --keep

Keep the existing resistance to temperature mapping defined in the configuration file/s and use that to
estimate hotplate temperature. If specified, this will allow the execution of this command without a
temperature sensing device configured. By default, any existing temperature calibration is ignored by the
calibration.

=head1 TEMPERATURE MEASUREMENT

To effectively run this calibration, the software needs to be able to take independent temperature measurements of
the working surface of the hotplate. This generally means using an instrument that can integrate with your PC and
stream temperature readings to it. Some of the options for this are listed below:

=head2 EEVBlog 121GW Multimeter

An integration module for this multimeter is available in the PowerSupplyControl::Controller::Device::EEVBlog121GW
module. It currently integrates by wrapping the bluetoothctl command line tool to connect to the multimeter and
subscribe to it's indications. It's a little clunky, but it works well enough. It does seem to drop bytes here and
there which means that it ends up dropping those temperature readings, but since it's streaming readings about
once every 500 milliseconds, missing a few reading here and there is not a big deal. In the places where these
readings are most important, they're changing relatively slowly, so even if you miss 3 in a row and don't get any
updated temperature readings in a given sampling period as a result, the most recently received reading is likely
still close enough to be useful. If you have the time and motivation to write a better integration - perhaps
based on an XS or FFI::Platypus integration, feel free to submit a pull request.

=head2 Arduino/Bluepill/etc based thermistor rig

If you have a decent prototyping board lying around like an Arduino or a Bluepill or a Seeduino Xiao and any of the
myriad others on the market, you can set that up with a thermistor divider and use that as a streaming temperature
sensor for the purposes of calibrating your hotplate. It's maybe not as elegant as a commercial multimeter, but
it works. An example Arduino sketch will be provided that you can customize to the needs of your particular
board and thermistor.

=head2 Other Digital Multimeters

If you have some other digital multimeter that can take temperature readings with a thermocouple and can be read
remotely via Bluetooth, USB, RS232 or some other means, you may be able to use that, but you'll need to implement
a device interface module for it. The interface is described in the PowerSupplyControl::Controller::Device.pm file
and you can also look at the EEVBlog121GW and ArduinoSerial modules for example implementations of this interface.

=head2 Metallurgical Standards

You can use solder alloys themselves as temperature reference standards, although unfortunately not with this
articular calibration routine. This calibration routine is designed to run at fixed power levels. This means we
don't know exactly which temperature we need to measure until we run the calibration cycle and it probably won't
be at the exact melting point of any of the alloys you use. There's also no way for the command to know when a
given sample has melted, either and that's a requirement for this calibration routine. See the ramp command for
more information about how to calibrate your resistance to temperature mapping against a metallurgical standard.

After doing a calibration against your metallurgical standard using the ramp command, you may be able to come
back and run this calibration routine with the --keep option to use your ramp calibration results and the
RTD temperature readings from your heating element to produce thermal resistance and heat capacity mappings.

=head2 Digital Kitchen Thermometer

While these can be used as a temperature reference for calibration purposes, they generally don't have remote
integration capabilities, so they're not usable with this calibration routine. See the ramp command for more
information on how you might be able to calibrate your hotplate using your Mum's handy digital kitchen thermometer.

As with the metallurgical standard calibration option, you can use the ramp command to calibrate your hotplate
resistance to temperature mapping and then come back to this calibration routine to produce thermal resistance
and heat capacity mappings using the --keep option.

=head1 METHODS

=head2 defaults

Return a hash of default configuration values for this command.

=cut

sub defaults {
  return { 'power-step' => 10
         , 'step-duration' => 450
         , 'maximum-temperature' => 220
         , 'discard-samples' => 4
         , filename => 'thermal-calibration.yaml'
         , samples => 10
         };
}

sub infoMessage {
  my $self = shift;
  
  $self->info(<<'EOS');
You are about to begin a calibration cycle for your hotplate.

   - This may take a while - up to 90 minutes or so.

   - You will need to have an external temperature sensor connected for the calibration.

   - Your hotplate should be at ambient temperature.

   - Turn off any unnecessary HVAC system.

   - Avoid any rapid movements near the hotplate. The resulting air movement may affect the calibration.

   - Don't leave the hotplate unattended during the calibration. It will probably be fine, but on the off chance that it's not you will probably enjoy having a house more than not having a house.
EOS
}

=head2 options

Return a hash of options for Getopt::Long parsing of the command line arguments.

=cut

sub options {
  return ( 'keep' );
}

=head2 initialize

Initialize the calibrate command.

=cut

sub initialize {
  my ($self) = @_;
  my $config = $self->{config};

  # Set up internal variables for the first step

  # The step counter. This helps identify how to transition to the next step when this one completes.
  $self->{step} = 0;

  # The power level that will be applied throughout this step.
  $self->{power} = $config->{'power-step'};

  # The time in seconds when this step will end.
  $self->{'step-end'} = $config->{'step-duration'};

  # The maximum temperature to watch for while the steps run.
  $self->{'maximum-temperature'} = $config->{'maximum-temperature'};

  # Give the step a name
  $self->{'step-name'} = 'rising-'. $self->{power};

  $self->{stage} = 'steps';
}

sub _nextStep {
  my ($self, $status) = @_;
  my $config = $self->{config};
  my $step = $self->{step};

  if ($step == 0) {
    $self->{power} += $config->{'power-step'};
    $self->{'step-name'} = 'rising-'. $self->{power};
  } elsif ($step % 2 == 0) {
    $self->{power} += 2 * $config->{'power-step'};
    $self->{'step-name'} = 'rising-'. $self->{power};
  } else {
    $self->{power} -= $config->{'power-step'};
    $self->{'step-name'} = 'falling-'. $self->{power};
  }

  $self->{'step-end'} += $config->{'step-duration'};
  $self->{step}++;
  $self->beep;

  return $self;
}

=head2 _steps($status)

Handle a timer event. This command doesn't really need the state-machine implementation, so it
overrides the timerEvent method to do what's needed.

=cut

sub _steps { 
  my ($self, $status) = @_;
  my $config = $self->{config};
  
  # Clean up any timer jitter
  my $clean_now = round($status->{now} / $status->{period}) * $status->{period};

  my $temperature = $status->{temperature};
  if (exists $self->{'device-temperature'}) {
    $temperature = $status->{'device-temperature'};
    $self->{'temperature-key'} = 'device-temperature';
  }

  if ( $temperature > $self->{'maximum-temperature'} && $self->{'step-name'} =~ /rising/) {
    $self->beep;
    $self->info('Maximum temperature reached. Starting final step.');
    $self->{step}++;
    $self->{power} -= $config->{'power-step'};
    $self->{'step-name'} = 'falling-'. $self->{power};
    $self->{'step-end'} = $clean_now +$config->{'step-duration'};
    $self->{final} = 1;
  }

  if ($clean_now >= $self->{'step-end'}) {
    if ($self->{final}) {
      # Set minimum power because we need to cool down to ambient temperature.
      return $self->_setupCoolDown($status);
    }
    $self->_nextStep;
  }

  $status->{stage} = $self->{'step-name'};
  $status->{step} = $self->{step};
  $status->{'step-end'} = $self->{'step-end'};
  $status->{'step-power'} = $self->{power};

  $self->{interface}->setPower($self->{power});

  return $self;
}

sub _setupCoolDown {
  my ($self, $status) = @_;

  my ($vmin, $vmax) = $self->{interface}->getVoltageLimits;
  $self->{interface}->setVoltage($vmin);

  $self->_doThermalCalibrations($status, $status->{'event-loop'}->getHistory);

  # Create a Bang-Bang controller that we will use for the calibration reflow cycle
  my $config = { hysteresis => 3
               , temperatures => $self->{'rt-mapping'}
               , 'thermal-resistance' => $self->{'thermal-resistance'}
               , 'heat-capacity' => $self->{'heat-capacity'}
               , 'predict-time-constant' => 0
               , 'predict-alpha' => 1
               };
  my $controller = PowerSupplyControl::Controller::BangBang->new($config, $self->{interface});

  # Don't lose our device!
  $controller->setDevice($self->{controller}->getDevice);
  $self->{'controller'} = $controller;

  return $self->advanceStage('cooldown');
}

sub _coolDown {
  my ($self, $status) = @_;
  my $config = $self->{config};

  if ($status->{'device-temperature'} <= $self->{ambient} + $self->{'ambient-tolerance'}) {
    $self->info('Hotplate is at ambient temperature. Starting delay filter calibration.');
    $self->{'reflow-stages'} = PowerSupplyControl::Math::PiecewiseLinear->new->addPoint(0,0);
    my $end = $status->{now};
    foreach my $stage (@{$config->{profile}}) {
      $end += $stage->{seconds};
      $self->{'reflow-stages'}->addPoint($end, $stage->{temperature});
    }
    $self->{'reflow-end'} = $end;

    return $self->advanceStage('reflow');
  }

  my ($vmin, $vmax) = $self->{interface}->getVoltageLimits;
  $self->{interface}->setVoltage($vmin);

  return $self;
}

sub _reflow {
  my ($self, $status) = @_;
  
  if ($status->{now} >= $self->{'reflow-end'}) {
    $self->info('Reflow cycle complete.');
    $self->{interface}->on(0);
    $self->beep;

    return;
  }

  $status->{'now-temperature'} = $self->{'reflow-stages'}->estimate($status->{now});
  $status->{'then-temperature'} = $self->{'reflow-stages'}->estimate($status->{now} + $status->{period});
  my $power = $self->{'controller'}->getRequiredPower($status);
  $status->{'set-power'} = $power;
  
  $self->{interface}->setPower($power);

  

  return $self;
}

sub _doPowerSegmentation {
  my ($self, $status, $history) = @_;
  my $buckets = {};
  my $temperature_key = undef;

  foreach my $sample (@$history) {
    if ($sample->{event} eq 'timerEvent') {
      if (!defined $temperature_key && exists $sample->{'device-temperature'}) {
        $temperature_key = 'device-temperature';
      }

      my $direction = $sample->{stage};

      next unless $direction =~ /^(rising|falling)-(\d+)$/;
      my $key = $2;
      $direction = $1;

      if (!exists $buckets->{$key}->{$direction}) {
        $buckets->{$key}->{$direction} = [];
      } 

      push @{$buckets->{$key}->{$direction}}, $sample;
    }
  }

  if (defined $temperature_key) {
    $self->{'temperature-key'} = $temperature_key;
  } else {
    $self->{'temperature-key'} = 'temperature';
  }

  return $buckets;
}

sub _calculateRTCalibrationPoint {
  my ($self, $bucket, $stats) = @_;
  my $config = $self->{config};
  my $samples = $config->{'tail-samples'} || $config->{'samples'} || 10;
  my $temperature_key = $self->{'temperature-key'};
  
  # Get the last 10 sample points for each direction
  my @rising = @{$bucket->{'rising'}}[-$samples..-1];

  # Don't discard samples here - that's only for curve fitting. We really need to consider the whole range, here.
  my ($rising_min_temp, $rising_max_temp);
  minimum($bucket->{rising}, $temperature_key => $rising_min_temp);
  maximum($bucket->{rising}, $temperature_key => $rising_max_temp);
  my $rising_range = $rising_max_temp - $rising_min_temp;

  my $rising_mean = {};
  mean(\@rising, $temperature_key => $rising_mean->{temperature}
               , resistance       => $rising_mean->{resistance}
               , power            => $rising_mean->{power}
               );

  $stats->{'rising-min-temperature'} = $rising_min_temp;
  $stats->{'rising-max-temperature'} = $rising_max_temp;
  $stats->{'rising-range'} = $rising_range;
  $stats->{'rising-centre-temperature'} = ($rising_max_temp + $rising_min_temp) / 2;

  # We may not have a falling step, since the last rising step won't have one.
  if ($bucket->{falling} && @{$bucket->{falling}} > 2*$samples) {
    my @falling = @{$bucket->{'falling'}}[-$samples..-1];

    my ($falling_min_temp, $falling_max_temp);
    minimum($bucket->{falling}, $temperature_key => $falling_min_temp);
    maximum($bucket->{falling}, $temperature_key => $falling_max_temp);
    my $falling_range = $falling_max_temp - $falling_min_temp;

    my $falling_mean = {};
    mean(\@falling, $temperature_key => $falling_mean->{temperature}
                 , resistance        => $falling_mean->{resistance}
                 , power             => $falling_mean->{power}
                 );

    my $rising_falling_ratio = $rising_range / $falling_range;

    my $temperature = ($rising_mean->{temperature} + $falling_mean->{temperature} * $rising_falling_ratio) / (1 + $rising_falling_ratio);
    my $power       = ($rising_mean->{power}       + $falling_mean->{power}       * $rising_falling_ratio) / (1 + $rising_falling_ratio);
    my $resistance  = ($rising_mean->{resistance}  + $falling_mean->{resistance}  * $rising_falling_ratio) / (1 + $rising_falling_ratio);
    my $thermal_resistance = ($temperature - $self->{ambient}) / $power;

    $stats->{'equilibrium-resistance'} = $resistance;
    $stats->{'equilibrium-temperature'} = $temperature;
    $stats->{'equilibrium-power'} = $power;
    $stats->{'thermal-resistance'} = $thermal_resistance;
    $stats->{'falling-min-temperature'} = $falling_min_temp;
    $stats->{'falling-max-temperature'} = $falling_max_temp;
    $stats->{'falling-range'} = $falling_range;
    $stats->{'falling-centre-temperature'} = ($falling_max_temp + $falling_min_temp) / 2;

    my $result = { temperature => $temperature
                 , 'thermal-resistance' => $thermal_resistance
                 };

    # Only return resistance if we have device temperatures, otherwise we don't want to overwrite the existing R-T mapping.
    if ($temperature_key eq 'device-temperature') {
      $result->{resistance} = $resistance;
    }

    return $result;
  }

  return;
}

sub _buildRTMapping {
  my ($self, $buckets) = @_;

  # Build a calibration point around the equilibrium point for each power level.
  # Note that it won't be at exactly the equilibrium point because we don't know
  # where that is yet, but that doesn't matter. We just need a resitance to temperature
  # calibration point that we trust.
  my @points;
  my $temperature_key = undef;

  foreach my $power (keys %$buckets) {
    if ($power =~ /^\d+$/) {
      $buckets->{stats}->{$power} = { power => $power };

      my $point = $self->_calculateRTCalibrationPoint($buckets->{$power}, $buckets->{stats}->{$power});
      push @points, $point if $point;
    }
  }

  @points = sort { $a->{resistance} <=> $b->{resistance} } @points;

  # Extrapolate the resistance line to 20C for a cold resistance estimate
  my $slr = PowerSupplyControl::Math::SimpleLinearRegression->new->addHashData(temperature => resistance => @points);

  # Flatten the thermal resistance curve at each end so we don't go off into wildly unrealistic numbers
  unshift @points, { temperature => 20
                   , resistance => $slr->predict(20)
                   , 'thermal-resistance' => $points[0]->{'thermal-resistance'}
                   };
  push @points, { temperature => max(220, $points[-1]->{temperature}+1)
                , 'thermal-resistance' => $points[-1]->{'thermal-resistance'}
                };

  return \@points;
}

sub _calculateHeatCapacityImpl {
  my ($self, $est, $samples, $stats) = @_;
  my $temperature_key = $self->{'temperature-key'};

  my $epsilon = $self->{config}->{'curve-fitting-epsilon'} || 0.05;

  # Need to provide shifted times to move t=0 to the start of the curve
  foreach my $sample (@$samples) {
    $sample->{'hc-now'} = $sample->{now} - $samples->[0]->{now};
  }

  my $final_temp;
  if (exists $stats->{'equilibrium-temperature'}) {
    $final_temp = $stats->{'equilibrium-temperature'};
  } else {
    # If we don't have an equilibrium temperature, start with the temperature of the last sample as our first guess.
    $final_temp = $samples->[-1]->{$temperature_key};
  }

  my $result = $est->fitCurve($samples, $temperature_key, 'hc-now', final => $final_temp);
  # Don't trust the first result if we didn't have a real equilibrium temperature to start with.
  my $first_result = undef;
  if (exists $stats->{'equilibrium-temperature'}) {
    $first_result = $result;
  }

  # Iteratively fit the curve until the final temperature is stable.
  # Set a limit on the number of iterations
  my $iterations = 50;

  # Track the difference between iterations to make sure it's getting smaller, otherwise the
  # result may be diverging wildly and we should stop!
  my $last_delta = 10000;

  while ($iterations--) {
    my $delta = abs($result->{final} - $final_temp);

    if ($delta < $epsilon) {
      if (!exists $result->{capacitance}) {
        # If we don't have capacitance, it's because we didn't have thermal resistance, so
        # calculate thermal resistance from our converged final temperature and the power.
        # Then calculate capacitance.
        my $thermal_resistance = ($result->{final} - $self->{ambient}) / $stats->{power};
        $result->{'thermal-resistance'} = $thermal_resistance;
        $result->{capacitance} = $result->{tau} / $thermal_resistance;
      }
      return $result;
    }

    if ($delta < $last_delta) {
      $final_temp = $result->{final};
      $last_delta = $delta;
      $result = $est->fitCurve($samples, $temperature_key, 'hc-now', final => $final_temp);
    } else {
      warn "Curve fitting diverged for power level $stats->{power}. Last delta: $last_delta, current delta: $delta\n";
      return $first_result;
    }
  }

  warn "Curve fitting did not converge for power level $stats->{power} after 50 iterations.\n";
  return $first_result;
}

sub _calculateHeatCapacity {
  my ($self, $bucket, $stats) = @_;
  my $config = $self->{config};
  my $power = $stats->{power};
  my $samples = $config->{'discard-samples'} || 4;
  my $knee_ratio = $config->{'knee-ratio'} || 0.75;
  my $result = undef;

  # TODO: This is a bit of a hack. We should probably build a piecewise linear estimator and get
  # the predicted thermal resistance at the centre rather than just using the value for the equilibrium
  # temperature, but it should be pretty close, so maybe good enough for now. It's not like we're trying
  # to land a rocket on a comet millions of miles away or something. We just need to make some solder
  # paste hot enough to melt, right?
  my $est = PowerSupplyControl::Math::FirstOrderStepEstimator->new(regressionThreshold => $knee_ratio
                                                                 , resistance => $stats->{'thermal-resistance'}
                                                                 );

  # Rising and falling results usually don't align well, so we prefer the rising result
  # due to better resolution, lower noise sensitivity and copper usually being better behaved
  # in expansion (heating up) versus contraction (cooling down).
  my @rising = @{$bucket->{rising}}[$samples..$#{$bucket->{rising}}];
  my $rising_result = $self->_calculateHeatCapacityImpl($est, \@rising, $stats);
  if ($rising_result) {
    $result->{temperature}     = $stats->{'rising-centre-temperature'};
    $result->{'heat-capacity'} = $rising_result->{capacitance};
    $result->{tau}             = $rising_result->{tau};
  }

  if ($bucket->{falling} && @{$bucket->{falling}} > 2*$samples) {
    my @falling = @{$bucket->{falling}}[$samples..$#{$bucket->{falling}}];
    my $falling_result = $self->_calculateHeatCapacityImpl($est, \@falling, $stats);

    if ($falling_result) {
      $result->{'falling-heat-capacity'} = $falling_result->{capacitance};
      $result->{'falling-temperature'}   = $stats->{'falling-centre-temperature'};
      $result->{'falling-tau'}           = $falling_result->{tau};
    }
  }

  return $result;
}

sub _buildHeatCapacityMapping {
  my ($self, $buckets) = @_;

  my @points;
  foreach my $power (keys %$buckets) {
    if ($power =~ /^\d+$/) {
      my $point = $self->_calculateHeatCapacity($buckets->{$power}, $buckets->{stats}->{$power});
      push @points, $point if $point;
    }
  }

  @points = sort { $a->{temperature} <=> $b->{temperature} } @points;

  # Add a point to flatten the curve at each end so we don't go off into wildly unrealistic numbers
  unshift @points, { temperature => min(20, $points[0]->{temperature}-1), 'heat-capacity' => $points[0]->{'heat-capacity'} };
  push @points, { temperature => max(220, $points[-1]->{temperature}+1), 'heat-capacity' => $points[-1]->{'heat-capacity'} };

  return \@points;
}

sub _doThermalCalibrations {
  my ($self, $status, $history) = @_;
  my ($buckets, $r_t, $t_hc);

  $buckets = $self->_doPowerSegmentation($status, $history);

  $r_t = $self->_buildRTMapping($buckets);

  $t_hc = $self->_buildHeatCapacityMapping($buckets);

  my $fh = $self->replaceFile($self->{config}->{filename});
  $self->writeCalibrationHeader($fh, %{$self->{config}});

  if ($self->{'temperature-key'} eq 'device-temperature') {
    $self->writeCalibration($fh, temperatures => $r_t, qw(resistance temperature));
  } else {
    # Re-write the existing controller R-T mapping so we don't lose that in the new configuration file
    my $points = [ $self->{controller}->getTemperaturePoints ];
    $self->writeArrayCalibration($fh, temperatures => $points, qw(resistance temperature));
  }

  $self->writeCalibration($fh, 'thermal-resistance' => $r_t, qw(temperature thermal-resistance));
  $self->writeCalibration($fh, 'heat-capacity' => $t_hc, qw(temperature heat-capacity));

  $fh->flush;
  $self->{filehandle} = $fh;
  $self->{'rt_mapping'} = $r_t;
  $self->{'hc_mapping'} = $t_hc;

  return $fh;
}

# Calculate the sum of squared error for a given delay filter alpha
sub _calculateDelaySquaredError {
  my ($self, $samples, $threshold, $tau) = @_;

  my $sum_err2 = 0;
  my $iir = $samples->[0]->{temperature};
  my $period = $samples->[0]->{period};
  my $alpha = $period / ($period + $tau);
  my $alpha2 = 1 - $alpha;

  foreach my $sample (@$samples) {
    $iir = $alpha * $sample->{temperature} + $alpha2 * $iir;

    if ($threshold->($sample->{temperature})) {
      my $err = $iir - $sample->{'device-temperature'};
      $sum_err2 += $err * $err;
    }
  }

  return $sum_err2;
}

sub _calculateDelayFilter {
  my ($self, $status, $samples) = @_;
  my $threshold = $self->{config}->{reflow}->{'profile-threshold'} // 160;

  my $above_threshold = sub { return $self->_calculateDelaySquaredError($samples, sub { return shift() > $threshold }, shift()); };
  my $below_threshold = sub { return $self->_calculateDelaySquaredError($samples, sub { return shift() <= $threshold }, shift()); };

  return ( minimumSearch($above_threshold, 0, 100, threshold => 0.001)
         , minimumSearch($below_threshold, 0, 100, threshold => 0.001)
         );
}

sub postprocess {
  my ($self, $status, $history) = @_;

  my $fh = $self->{filehandle};
  if (!$fh) {
    $fh = $self->_doThermalCalibrations($status, $history);
  }

  my @samples = ();
  foreach my $sample (@$history) {
    if ($sample->{event} eq 'timerEvent' &&  $sample->{stage} eq 'reflow' && exists $sample->{'device-temperature'}) {
      push @samples, $sample;
    }
  }
  my ($tau, $tau_low) = $self->calculateDelayFilter($status, \@samples);

  $fh->print("predict-time-constant: $tau\n\n");
  $fh->print("predict-time-constant-low: $tau_low\n\n");
  $fh->close;

  $self->_catFile($self->{config}->{filename});

  $self->beep;

  return 1;
}

sub _catFile {
  my ($self, $filename) = @_;

  if (! -f $filename) {
    $filename = PowerSupplyControl::Config->findConfigFile($filename);
  }

  if ($filename && -f $filename && -r $filename) {
    my $fh = IO::File->new($filename, 'r');
    if ($fh) {
      while (my $line = $fh->getline) {
        print $line;
      }
    }
  }

  return;
}

1;