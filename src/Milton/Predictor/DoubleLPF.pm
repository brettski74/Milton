package Milton::Predictor::DoubleLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Predictor);

=encoding utf8

=head1 NAME

Milton::Predictor::DoubleLPF - Dual Low Pass Filter Temperature Predictor

=head1 SYNOPSIS

  use Milton::Predictor::DoubleLPF;
  
  # Create a predictor with default parameters
  my $predictor = Milton::Predictor::DoubleLPF->new();
  
  # Create a predictor with custom parameters
  my $predictor = Milton::Predictor::DoubleLPF->new(
    'inner-tau'      => 3,   # Inner filter time constant in seconds
    'outer-offset'   => 300, # Outer filter offset parameter
    'outer-gradient' => 0    # Outer filter gradient parameter
  );
  
  # Predict hotplate temperature from heating element temperature
  my $status = {
    temperature => 150,    # Heating element temperature (°C)
    ambient     => 25,     # Ambient temperature (°C)
    period      => 1.5     # Time between successive samples in seconds
  };
  
  my $predicted_temp = $predictor->predictTemperature($status);

=head1 DESCRIPTION

C<Milton::Predictor::DoubleLPF> is an improved temperature prediction model that estimates hotplate 
temperature based on measurements of the heating element temperature. This predictor uses a dual 
low-pass filter approach to more accurately model the thermal dynamics between the heating element 
and hotplate, including heat loss to the ambient environment.

The prediction model works by applying two cascaded low-pass filters:

=over

=item 1. **Inner Low-Pass Filter**

Pulls the hotplate temperature towards the heating element temperature, modeling the heat transfer 
from the heating element to the hotplate surface.

=item 2. **Outer Low-Pass Filter**

Pulls the hotplate temperature back down towards the ambient temperature, modeling heat loss to 
the ambient environment. The time constant of this filter varies with temperature to account for 
changes in effective thermal mass and effective thermal resistance to ambient as temperature
varies.

=back

The mathematical model uses the following cascaded approach:

    # Inner filter: heating element -> hotplate
    alpha_inner = period / (period + inner_tau)
    intermediate_temp = temperature * alpha_inner + (1 - alpha_inner) * last_prediction
    
    # Outer filter: hotplate -> ambient
    outer_tau = outer_gradient * intermediate_temp + outer_offset
    alpha_outer = period / (period + outer_tau)
    prediction = ambient * alpha_outer + (1 - alpha_outer) * intermediate_temp

Where:

=over

=item C<inner_tau>

C<inner_tau> is the time constant for heat transfer from heating element to hotplate

=item C<intermediate_temp>

C<intermediate_temp> is the intermediate temperature calculated prior to accounting for heat loss to ambient

=item C<outer_offset>

C<outer_offset> is the base time constant for heat loss to ambient

=item C<outer_gradient>

C<outer_gradient> controls how the ambient heat loss time constant varies with temperature

=back

=head1 PARAMETERS

=head2 inner-tau

The time constant of the inner low-pass filter in seconds. This parameter controls how quickly 
the hotplate temperature responds to changes in heating element temperature. This models the 
heat transfer from the heating element to the hotplate surface.

=over

=item * Default

27 seconds

=item * Range

0 to infinite, although values greater than 30 seconds are unlikely to be realistic.

=item * Typical values

1.5-3 seconds for aluminium substrates, 25-30 seconds for FR4 substrates.

=item * Assumptions

100mm x 100mm PCB hotplate

=back

=head2 outer-offset

The base time constant for heat loss to the ambient environment in seconds. This parameter 
represents the time constant for ambient heat loss at ambient temperature. At higher temperatures, 
the effective time constant typically becomes shorter due to the outer-gradient parameter.

=over

=item * Default

300 seconds

=item * Range

200 to infinite. 

=item * Typical values

Typical values are in the low hundreds of seconds, however, values into the low thousands of
seconds may be useful for specific use-cases if paired with a suitable outer-gradient parameter.

=item * Physical meaning

Lower values generally indicate faster heat loss to the ambient environment.

=back

=head2 outer-gradient

A dimensionless parameter that controls how the ambient heat loss time constant varies with 
temperature. Negative values cause the heat loss time constant to decrease (faster heat loss) 
as temperature increases, which is physically realistic due to increased radiative and 
convective heat transfer at higher temperatures and other effects.

=over

=item * Default

0 (constant heat loss time constant)

=item * Range

-20 to 0, where negative values indicate increased heat loss at higher temperatures. Technically,

=item * Typical values

-10 to 0. Values outside this range are unlikely to be useful based on current experience.

=item * Physical meaning

More negative values indicate stronger temperature dependence of ambient heat loss.

For materials like FR4, the variation in effective thermal mass and effective thermal resistance
can be complicated, so a linear model for variation may be limited and tuned parameters are likely
most appropriate for temperature profiles that match well with the temperature profile of the
tuning data. Materials like aluminium are more linear in their behaviour, but there are still
non-linear effects due to the non-linear behaviour of convection, radiation and conduction in
real-world systems.

=back

=head1 CONSTRUCTOR

=head2 new(%options)

Creates a new DoubleLPF predictor instance.

=over

=item C<inner-tau>

Time constant for inner filter in seconds (default: 27)

=item C<outer-offset>

Base time constant for outer filter in seconds (default: 300)

=item C<outer-gradient>

Temperature gradient for outer filter time constant (default: 0)

=item C<logger> (Optional)

An object implementing the L<Milton::DataLogger> interface that may be used for error, information or debug output.

=back

=head1 METHODS

=head2 predictTemperature($status)

Predicts the hotplate temperature based on the current heating element temperature and system state.

=over

=item C<$status>

Status hash containing details of the current system state. The following keys are used by this method:

=over

=item C<ambient>

Ambient temperature (°C)

=item C<period>

Time period since last prediction (seconds)

=item C<temperature>

Current heating element temperature (°C)

=back

=item Return Value

Predicted hotplate temperature (°C)

=item Side Effects

Updates C<last-prediction> in this object and C<predict-temperature> in C<$status>

=back

=head2 initialize()

Resets the predictor's internal state by clearing the last prediction. This method is mostly used
during tuning to reset the internal state of the predictor between successive tuning cycles.

=head2 tune($samples, %args)

Tunes the predictor parameters using historical temperature data to minimize prediction error.

=over

=item C<$samples>

Array reference of historical temperature samples. These hashes should have the same structure as the
C<$status> hash passed to the C<predictTemperature> method.

=item C<%args>

Additional tuning options. Refer to the L<Milton::Math::Util::minimumSearch> subroutine for details.
The parameters being tuned are C<inner-tau>, C<outer-offset>, and C<outer-gradient>.

=item Return Value

Hash reference with tuned parameter values.

=item Side Effects

Updates the C<inner-tau>, C<outer-offset>, and C<outer-gradient> parameters in this object to the tuned values.
Modifies the C<last-prediction> value in this object.

=back

=head2 description()

Returns a human-readable description of the predictor with current parameter values.

=head1 USAGE EXAMPLES

=head2 Basic Usage

  use Milton::Predictor::DoubleLPF;
  
  my $predictor = Milton::Predictor::DoubleLPF->new();
  
  # Predict temperature during heating
  my $status = {
    temperature => 180,  # Heating element at 180°C
    ambient     => 25,   # Room temperature
    period      => 1.5   # 1.5 seconds since last update
  };
  
  my $hotplate_temp = $predictor->predictTemperature($status);
  print "Predicted hotplate temperature: ${hotplate_temp}°C\n";

=head2 Custom Parameters

  # Create predictor optimized for your specific system
  my $predictor = Milton::Predictor::DoubleLPF->new(
    'inner-tau'      => 3,   # Fast response for aluminium substrate
    'outer-offset'   => 600, # Better insulation
    'outer-gradient' => -2   # Significant temperature-dependent heat loss
  );

=head2 Tuning Parameters

  # Tune parameters using historical data
  my $tuned_params = $predictor->tune($historical_samples, 
    threshold => [ 0.001, 0.01, 0.0001 ],  # Different thresholds for each parameter
    steps     => [ 32, 64, 32 ],           # Search resolution for each parameter
    bias      => 1,                        # Apply bias scaling
    depth     => 512                       # Search depth
  );
  
  print "Tuned inner-tau: $tuned_params->{'inner-tau'}\n";
  print "Tuned outer-offset: $tuned_params->{'outer-offset'}\n";
  print "Tuned outer-gradient: $tuned_params->{'outer-gradient'}\n";

=head1 THERMAL MODEL DETAILS

The DoubleLPF predictor models the thermal system as a cascaded first-order system:

=over

=item * **Heating Element**: The primary heat source with measured temperature.

=item * **Inner Thermal Mass and Resistance**: Modeled by the inner-tau time constant, representing heat transfer from heating element to hotplate.

=item * **Hotplate**: The target whose temperature is being predicted.

=item * **Outer Thermal Mass and Resistance**: Modeled by the temperature-dependent outer time constant, representing heat loss to ambient environment.

=item * **Ambient Environment**: The heat sink with constant temperature.

=back

The model assumes:

- Constant linear heat transfer from the heating element to the hotplate assembly

- Temperature-dependent heat loss to ambient (via outer-gradient and outer-offset)

- Linearly varying thermal losses to ambient over the operating temperature range

- Negligible heat transfer directly from heating element to ambient

=head1 ADVANTAGES OVER LossyLPF

Compared to L<Milton::Predictor::LossyLPF>, this model provides:

=over

=item * More flexible modeling of ambient heat loss due to the temperature-dependent outer filter

=item * Temperature-dependent heat loss characteristics

=item * More physically realistic thermal dynamics

=back

=head1 LIMITATIONS

=over

=item * Does not account for non-linear variation in effective thermal mass versus temperature

=item * Does not account for non-linear variation in effective thermal resistance versus temperature

=item * Requires current ambient temperature measurement

=back

=head1 SEE ALSO

=over

=item * L<Milton::Predictor> - Base predictor class

=item * L<Milton::Predictor::LossyLPF> - Simpler single-filter model

=item * L<Milton::Predictor::BandedLPF> - An improved model that models arbitrary variation in thermal properties across the operating temperature range

=item * L<Milton::Math::Util> - Mathematical utilities used for tuning

=item * L<Milton::Controller> - Controller classes that use this predictor

=back

=head1 AUTHOR

Milton Controller Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{'inner-tau'} //= 27;
  $self->{'outer-gradient'} //= 0;
  $self->{'outer-offset'} //= 300;

  return $self;
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $last_prediction = $self->{'last-prediction'};
  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $period = $status->{period};

    # Pull hotplate temperature towards heating element temperature
    my $alpha = $period / ($period + $self->{'inner-tau'});
    my $intermediate_temp = $status->{temperature} * $alpha + (1-$alpha) * $last_prediction;

    # And pull it back down to ambient temperature
    my $tau = $self->{'outer-gradient'} * $intermediate_temp + $self->{'outer-offset'};
    $alpha = $period / ($period + $tau);
    $prediction = $ambient * $alpha + (1-$alpha) * $intermediate_temp;
  } else {
    $prediction = $status->{temperature};
  }

  $self->{'last-prediction'} = $prediction;
  $status->{'predict-temperature'} = $prediction;

  return $prediction;
}

sub initialize {
  my ($self) = @_;
  delete $self->{'last-prediction'};
}

sub description {
  my ($self) = @_;
  return sprintf('DoubleLPF(inner-tau=%.3f, outer-offset=%.3f, outer-gradient=%.3f)',
                 $self->{'inner-tau'}, $self->{'outer-offset'}, $self->{'outer-gradient'});
}

sub tune {
  my ($self, $samples, %args) = @_;

  my $parallel = $self->{tuning}->{parallel} // 1;

  my $filtered = $self->filterSamples($samples);

  my $tuned = $self->_tune($filtered
                           , [ 'inner-tau', 'outer-offset', 'outer-gradient' ]
                           , [ [ 0, 30 ], [ 200, 4000 ], [ -20, 0 ] ]
                           , 'lower-constraint' => [ 0, 0, undef ]
                           , threshold => [ 0.001, 0.01, 0.0001 ]
                           , steps => [ 32, 64, 32 ]
                           , bias => 1
                           , depth => 512
                           , %args
                           );
  
  return $tuned;
}

1;