package PowerSupplyControl::ThermalModel;

use strict;
use warnings qw(all -uninitialized);
use Carp;

=head1 NAME

ThermalModel - A simple first-order thermal model for predicting temperature changes in a system.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides a simple first-order thermal model for predicting temperature changes in a system.
=head1 CONSTRUCTOR

=head2 new(\%args)

Create a new thermal model.

The following named parameters may be specified. At a minimum, the thermal resistance and heat capacity must be specified.
Note that it is generally assumed that temperatures are measured in Celsius or Kelvin, although the model itself is
agnostic to the unit of temperature. So long as the units are consistent, the model will work.

=over

=item resistance

Thermal resistance in Kelvin per watt. This parameter is mandatory, although it can be calculated from kp and kt.

=item capacity

Heat capacity in joules per Kelvin. This parameter is mandatory, although it can be calculated from kp and kt.

=item kp

Power coefficient of the model. This is ignored if resistance and capacity are specified.

=item kt

Temperature coefficient of the model. This is ignored if resistance and capacity are specified.

=item period

The sampling period of the model in seconds. This parameter is optional and defaults to 1 second.

=item ambient

Ambient temperature in Kelvin/Celsius. This parameter is optional and defaults to 20 units.

=back

=cut

sub new {
    my ($class, $args) = @_;
    my $self = {};

    bless $self, $class;

    # Defaulted parameters
    $self->ambient(defined $args->{ambient} ? $args->{ambient} : 20);
    $self->period(defined $args->{period} ? $args->{period} : 1);

    # Semi-optional parameters
    $self->capacity($args->{capacity}) if exists $args->{capacity} && defined $args->{capacity};
    $self->resistance($args->{resistance}) if exists $args->{resistance} && defined $args->{resistance};
    $self->kp($args->{kp}) if exists $args->{kp} && defined $args->{kp};
    $self->kt($args->{kt}) if exists $args->{kt} && defined $args->{kt};

    # Verify that mandatory model parameters are set
    croak "Thermal resistance is mandatory" unless defined $self->{resistance};
    croak "Heat capacity is mandatory" unless defined $self->{capacity};

    return $self;
}

=head1 METHODS

=head2 period($period)

Get/Set the sampling period of the model.

=over

=item $period

Optional parameter. If specified, updates the sampling period of the model.

=item Return Value

The method returns the previous value of the period.

=back

=cut

sub period {
    my $self = shift;
    my $period = $self->{period};

    return $period if @_ == 0;

    $self->{period} = shift;
    croak "Period must be greater than 0" if $self->{period} <= 0;

    if ($self->{k_dominant}) {
      $self->_setCapacity;
    } else {
      $self->_setKp;
      $self->_setKt;
    }

    return $period;
}

=head2 ambient($ambient)

Get/Set the ambient temperature of the model.

=over

=item $ambient

Optional parameter. If specified, updates the ambient temperature of the model.

=item Return Value

The method returns the previous value of the ambient temperature.

=back

=cut

sub ambient {  
    my $self = shift;
    my $ambient = $self->{ambient};

    if (@_) {
        $self->{ambient} = shift;
    }
    return $ambient;
}

=head2 resistance($resistance)

Get/Set the thermal resistance of the model.

=over

=item $resistance 

Optional parameter. If specified, updates the thermal resistance of the model.

=item Return Value

Optional parameter. The method returns the previous value of the thermal resistance.

=back

=cut

sub resistance {
  my $self = shift;
  my $resistance = $self->{resistance};

  if (@_) {
    $self->{resistance} = shift;
    $self->_setKt;
    $self->{k_dominant} = undef;
  }

  return $resistance;
}

sub _setResistance {
  my $self = shift;
  
  if ($self->{kt}) {
    if ($self->{kp}) {
      $self->{resistance} = $self->{kp} / $self->{kt};
    } else {
      $self->{resistance} = $self->{period} / ($self->{capacity} * $self->{kt});
    }
  }
}

=head2 capacity($capacity)

Get/Set the heat capacity of the model.

=over

=item $capacity

Optional parameter. If specified, updates the heat capacity of the model.

=item Return Value

Optional parameter. The method returns the previous value of the heat capacity.

=back

=cut

sub capacity {
  my $self = shift;
  my $capacity = $self->{capacity};

  if (@_) {
    $self->{capacity} = shift;
    $self->_setKp;
    $self->_setKt;
    $self->{k_dominant} = undef;
  }
  return $capacity;
}

sub _setCapacity {
  my $self = shift;

  if ($self->{kp}) {
    $self->{capacity} = $self->{period} / $self->{kp};
  } elsif ($self->{kt}) {
    $self->{capacity} = $self->{period} / ($self->{resistance} * $self->{kt});
    $self->{kp} = $self->{period} / $self->{capacity};
  }
}

=head2 kp($kp)

Get/Set the power coefficient of the model.

This value is dependent on the heat capacity and sampling period of the model and is calculated as:

kp = period / capacity

=over

=item $kp

Optional parameter. If specified, updates the power coefficient of the model.

=item Return Value

Optional parameter. The method returns the previous value of the power coefficient.

=back

=cut

sub kp {
  my $self = shift;
  my $kp = $self->{kp};

  if (@_) {
    $self->{kp} = shift;
    $self->_setCapacity;
    $self->_setResistance;
  }
  return $kp;
}

sub _setKp {
  my $self = shift;
  if ($self->{capacity}) {
    $self->{kp} = $self->{period} / $self->{capacity};
    $self->{k_dominant} = 'p';
  }
}

=head2 kt($kt)

Get/Set the temperature coefficient of the model.

This value is dependent on the thermal resistance, heat capacity and sampling period of the model and is calculated as:

kt = period / (resistance * capacity)

=over

=item $kt

Optional parameter. If specified, updates the temperature coefficient of the model.

=item Return Value

Optional parameter. The method returns the previous value of the temperature coefficient.

=back

=cut

sub kt {
  my $self = shift;
  my $kt = $self->{kt};

  if (@_) {
    $self->{kt} = shift;
    $self->_setCapacity;
    $self->_setResistance;
    $self->{k_dominant} = 't';
  }
  return $kt;
}

sub _setKt {
  my $self = shift;
  if ($self->{resistance}) {
    if ($self->{capacity}) {
      $self->{kt} = $self->{period} / ($self->{resistance} * $self->{capacity});
    } elsif ($self->{kp}) {
      $self->{kt} = $self->{kp} / $self->{resistance};
    }
  }
}
=head2 predictDeltaT($power, $temperature)

Predict the temperature change after a given power is applied.

The model is a simple first-order model that assumes that the temperature of the system is a function of the power applied to the system and the thermal resistance and heat capacity of the system.

The model is given by the following equation:

delta_T = kp * power + kt * (temperature - ambient)

=over

=item $power
The power that will be applied to the system in watts.

=item $temperature

The current temperature of the system.

=back

=cut

sub predictDeltaT {
    my ($self, $power, $temperature) = @_;
    my $delta_T = $power * $self->kp - ($temperature - $self->ambient) * $self->kt;
    return $delta_T;
}

=head2 predictPower($current_temp, $target_temp)

Predict the power required to achieve a given temperature change.

=over

=item $current_temp

The current temperature of the system.

=item $target_temp

The target temperature of the system after one sample period.

=back

=cut

sub predictPower {
  my ($self, $current_temp, $target_temp) = @_;
  my $power = ($target_temp - $current_temp + $self->{kt} * ($current_temp - $self->{ambient})) / $self->{kp};
  return $power;
}

1;