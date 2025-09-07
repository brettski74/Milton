package Milton::Controller::BangBang;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Controller::RTDController);

=encoding utf8

=head1 NAME

Milton::Controller::BangBang - Bang-bang controller with optional modulation

=head1 SYNOPSIS

  use Milton::Controller::BangBang;
  
  # Create controller based on configuration settings
  my $controller = Milton::Controller::BangBang->new($config, $interface);
  
  # Create controller with modulated power levels
  my $config = {
    'power-levels' => [
      { temperature => 25,  power => 80 },
      { temperature => 100, power => 60 },
      { temperature => 200, power => 40 }
    ],
    hysteresis => { low => 1.0, high => 0.5 }
  };
  
  my $controller = Milton::Controller::BangBang->new($config, $interface);

=head1 DESCRIPTION

C<Milton::Controller::BangBang> implements a bang-bang (on/off) control strategy for hotplate 
temperature control. This controller switches between high and low power states based on 
temperature error, with optional power modulation to reduce overshoot and improve control 
stability.

The controller supports both simple on/off control and modulated bang-bang control, where 
the "on" power level varies with temperature to provide smoother control characteristics.

=head1 CONTROL ALGORITHM

Bang-bang control is the simplest form of feedback control with two states:

=over

=item * **ON State**: Apply high power when temperature is below target

=item * **OFF State**: Apply minimum power when temperature is at or above target

=back

The controller uses hysteresis to prevent rapid switching around the target temperature. 
The hysteresis bands are configurable and can be asymmetric.

=head2 Modulated Bang-Bang Control

When power-level mappings are configured, the controller uses modulated bang-bang control:

=over

=item * **ON State**: Apply temperature-dependent power level (interpolated from power-levels)

=item * **OFF State**: Apply minimum power (from interface power limits)

=back

This may reduce overshoot and oscilation around the target temperature and provide smoother
control, especially at higher temperatures 
where full power would cause excessive heating.

=head1 PARAMETERS

=head2 power-levels

Array of temperature/power mappings for modulated control. When specified, the controller 
interpolates between these points to determine the power level for the ON state based on the current
temperature.

=over

=item C<temperature>

Temperature at which the power level applies (°C)

=item C<power>

Power level to use at this temperature (W)

=back

=over

=item * Default

Uses maximum interface power for all temperatures

=item * Typical Values

50W at 25°C, 70W at 100°C, 90W at 200°C

Note this is intended for control purposes not safety purposes, so you would normally require higher power
levesl at higher temperatures due to the faster rates of heat loss to the ambient environment at higher
temperatures. While this could also be used to implement safety limtis - and at one time it was - safety
limits are a separately configurable mechanism that can apply to all controllers, not just bang-bang.

=back

=head2 hysteresis

Hysteresis configuration to prevent rapid switching around target temperature.

=over

=item C<low>

Negative hysteresis band (°C) - controller turns ON when error < -low

=item C<high>

Positive hysteresis band (°C) - controller turns OFF when error >= high

=back

=over

=item * Default

low: 0.5°C, high: 0°C

=item * Typical Values

low: 1.0°C, high: 0.5°C for stable control

=back

=head1 CONSTRUCTOR

=head2 new($config, $interface)

Creates a new BangBang controller instance.

=over

=item C<$config>

Configuration hash containing:

=over

=item C<power-levels>

Optional array of temperature/power mappings for modulated control

=item C<hysteresis>

Optional hysteresis configuration (default: {low => 0.5, high => 0})

=item Standard RTDController configuration parameters

=back

=item C<$interface>

Interface object for power supply communication

=back

=head1 METHODS

=head2 getRequiredPower($status)

Calculates the required power using bang-bang control logic.

=over

=item C<$status>

Status hash containing:

=over

=item C<then-temperature>

Target temperature (°C)

=item C<predict-temperature>

Current predicted temperature (°C)

=back

=item Return Value

Power level to apply (W)

=item Side Effects

Updates internal ON/OFF state based on hysteresis logic

=back

=head2 setPowerLevel($temperature, $power)

Adds or updates a power level mapping for modulated control.

=over

=item C<$temperature>

Temperature at which the power level applies (°C)

=item C<$power>

Power level to use at this temperature (W)

=back

=head1 USAGE EXAMPLES

=head2 Basic Bang-Bang Control

  use Milton::Controller::BangBang;
  
  # Simple on/off control
  my $config = {
    hysteresis => { low => 1.0, high => 0.5 }
  };
  
  my $controller = Milton::Controller::BangBang->new($config, $interface);
  
  # Control loop
  while ($running) {
    my $status = $interface->getStatus();
    $status->{'then-temperature'} = 100;  # Target 100°C
    
    my $power = $controller->getRequiredPower($status);
    $interface->setPower($power);
    
    sleep(1);
  }

=head2 Modulated Bang-Bang Control

  # Modulated control with temperature-dependent power levels
  my $config = {
    'power-levels' => [
      { temperature => 25,  power => 50 },
      { temperature => 100, power => 70 },
      { temperature => 200, power => 90 }
    ],
    hysteresis => { low => 1.0, high => 0.5 }
  };
  
  my $controller = Milton::Controller::BangBang->new($config, $interface);

=head1 ADVANTAGES

=over

=item * Simple to implement and understand

=item * No complex tuning parameters required

=item * Robust and reliable operation

=item * Fast response to large temperature deviations

=item * Modulated control can reduce overshoot

=back

=head1 DISADVANTAGES

=over

=item * Continuous oscillation around setpoint

=item * Limited fine control near target temperature

=item * May cause higher wear on heating elements due to switching

=back

=head1 TUNING GUIDELINES

Realistically, there's really no tuning required, although if your power supply is capable of
very high power levels for your hotplate, you may wish to limit the power levels to keep the
oscillations down to more manageable levels. For a 100mm x 100mm aluminium PCB hotplate, 120W
is plenty of power for the on-state for most purposes. While it's possible to use lower power
at low temperatures, empirical experience suggests that it's not worth the extra effort.

=head2 Hysteresis Tuning

=over

=item * Larger hysteresis reduces switching frequency

=item * Larger hysteresis band increases amplitude of oscillation around the target temperature.

=item * Typical range: 0.5-2.0°C total hysteresis

Note that for a typical setup with a 100mm x 100mm alumninium PCB hotplate, 1.5 second sample
period and 120W of on-state power, the oscillations will likely favour the high side of the
reflow profile. For this reason, you probably want to set the high-side hysteresis to zero and
the low side hysteresis to something like 0.0-1.0°C depending on your hotplate and power supply.

=back

=head1 INHERITANCE

This class inherits from L<Milton::Controller::RTDController>, which provides:

=over

=item * Temperature measurement using heating element as RTD

=item * Resistance-temperature calibration support

=item * Safety limits and cutoff features

=item * Interface management

=back

=head1 SEE ALSO

=over

=item * L<Milton::Controller::RTDController> - Base class for RTD-based controllers

=item * L<Milton::Controller::HybridPI> - Advanced PI control with feed-forward

=item * L<Milton::Controller> - Controller base class

=item * L<Milton::Math::PiecewiseLinear> - Power level interpolation

=back

=head1 AUTHOR

Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  my $self = $class->SUPER::new($config, $interface);

  my ($pmin, $pmax) = $interface->getPowerLimits();

  if (defined $config->{'power-levels'}) {
    $self->{'on-power'} = Milton::Math::PiecewiseLinear->new
            ->addHashPoints('temperature', 'power', @{$config->{'power-levels'}});
  } else {
    $self->{'on-power'} = Milton::Math::PiecewiseLinear->new(20, $pmax);
  }

  # Set some defaults for the hysteresis if not specified in the configuration.
  # Handle legacy configuration if hysteresis is scalar - assume it's a number to be applied equally on both sides.
  if (!ref $self->{hysteresis}) {
    $self->{hysteresis} = {
      low => $self->{hysteresis},
      high => $self->{hysteresis},
    };
  }
  
  if (!defined $self->{hysteresis}->{low}) {
    $self->{hysteresis}->{low} = 0.5;
  } elsif ($self->{hysteresis}->{low} < 0) {
    $self->{hysteresis}->{low} = 0;
  }

  if (!defined $self->{hysteresis}->{high}) {
    $self->{hysteresis}->{high} = 0;
  } elsif ($self->{hysteresis}->{high} < 0) {
    $self->{hysteresis}->{high} = 0;
  }

  $self->{'min-power'} = $pmin;

  $self->{on} = 0;

  return $self;
}

sub getRequiredPower {
  my ($self, $status) = @_;

  my $on = $self->{on};
  my $target_temp = $status->{'then-temperature'};
  my $temperature = $self->{predictor}->predictTemperature($status);
  my $hyst_lo = -$self->{hysteresis}->{low};
  my $hyst_hi = $self->{hysteresis}->{high};

  my $error = $temperature - $target_temp;

  if ($error < $hyst_lo) {
    $self->{on} = 1;
  } elsif ($error >= $hyst_hi) {
    $self->{on} = 0;
  }

  return $self->{'on-power'}->estimate($temperature) if $self->{on};
  #return $self->{'on-power'}->estimate($status->{temperature}) if $self->{on};
  return $self->{'min-power'};
}

sub setPowerLevel {
  my ($self, $temperature, $power) = @_;

  $self->{'on-power'}->addPoint($temperature, $power);

  return;
}

1;
