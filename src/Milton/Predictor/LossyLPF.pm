package Milton::Predictor::LossyLPF;

use strict;
use warnings qw(all -uninitialized);

use base qw(Milton::Predictor);

=encoding utf8

=head1 NAME

Milton::Predictor::LossyLPF - Lossy Low Pass Filter Temperature Predictor

=head1 SYNOPSIS

  use Milton::Predictor::LossyLPF;
  
  # Create a predictor with default parameters
  my $predictor = Milton::Predictor::LossyLPF->new();
  
  # Create a predictor with custom parameters
  my $predictor = Milton::Predictor::LossyLPF->new(
    tau           => 3,   # Time constant in seconds
    'loss-factor' => 0.9  # Loss factor for temperature conversion
  );
  
  # Predict hotplate temperature from heating element temperature
  my $status = {
    temperature => 150,    # Heating element temperature (°C)
    ambient     => 25,     # Ambient temperature (°C)
    period      => 1.5     # Time between successive samples in seconds
  };
  
  my $predicted_temp = $predictor->predictTemperature($status);

=head1 DESCRIPTION

C<Milton::Predictor::LossyLPF> is a temperature prediction model that estimates hotplate temperature 
based on measurements of the heating element temperature. This predictor is specifically designed 
for systems where the heating element temperature is measured but the actual hotplate temperature 
needs to be estimated.

The prediction model works by:

=over

=item 1. **Relative Temperature Calculation**

Computes the temperature difference between the heating element and ambient temperature.

=item 2. **Loss Factor Application**

Applies a loss factor to account for the fact that during heating, the heating element temperature is
generally higher than the average hotplate temperature due to thermal gradients and heat transfer
inefficiencies.

=item 3. **Low Pass Filtering**

Applies a single-pole low pass filter to estimate the delay between changes in heating element
temperature and their effect on hotplate temperature.

=back

The mathematical model uses the following formula:

    T_predicted = T_ambient + (T_heating_element - T_ambient) * loss_factor * alpha + 
                  (1 - alpha) * (T_previous_prediction - T_ambient)

Where:

=over

=item C<alpha> = period / (period + tau)

=item C<tau>

The time constant of the low pass filter

=item C<loss_factor>

Accounts for thermal losses between heating element and hotplate

=back

=head1 PARAMETERS

=head2 tau

The time constant of the low pass filter in seconds. This parameter controls how quickly the 
prediction responds to changes in heating element temperature. A larger value results in slower 
response but more stable predictions. Highly conductive substrates like aluminium typically have
short time constants whereas less conductive substrates like FR4 will have longer time constants.

=over

=item * Default

27 seconds

=item * Range

0 to infinite, although values greated than 100 seconds are unlikely to be realistic.

=item * Typical values

1.5-3 seconds for aluminium substrates, 25-30 seconds for FR4 substrates.

=item * Assumptions

100mm x 100mm PCB hotplate

=back

=head2 loss-factor

A dimensionless factor that accounts for thermal losses between the heating element and the 
hotplate. This factor is applied to the relative temperature (heating element - ambient) to 
estimate the effective temperature rise of the hotplate. Values closer to 1.0 indicate more
efficient and/or faster heat transfer from the heating element to the hotplate.

=over

=item * Default

0.925

=item * Range

0.0 to 1.0, although values less than 0.9 are unlikely to be realistic.

=item * Typical values

0.99+ for aluminium substrates, 0.925 for FR4 substrates.

=item * Assumptions

100mm x 100mm PCB hotplate

=back

=head1 CONSTRUCTOR

=head2 new(%options)

Creates a new LossyLPF predictor instance.

=over

=item C<tau>

Time constant in seconds (default: 27)

=item C<loss-factor>

Loss factor for temperature conversion (default: 0.925)

=item C<logger>

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
The parameters being tuned are C<tau> and C<loss-factor>.

=item Return Value

Hash reference with tuned parameter values.

=item Side Effects

Updates the C<tau> and C<loss-factor> parameters in this object to the tuned values.
Modifies the C<last-prediction> value in this object.

=back

=head2 description()

Returns a human-readable description of the predictor with current parameter values.

=head1 USAGE EXAMPLES

=head2 Basic Usage

  use Milton::Predictor::LossyLPF;
  
  my $predictor = Milton::Predictor::LossyLPF->new();
  
  # Predict temperature during heating
  my $status = {
    temperature => 180,  # Heating element at 180°C
    ambient => 25,       # Room temperature
    period => 0.1        # 100ms since last update
  };
  
  my $hotplate_temp = $predictor->predictTemperature($status);
  print "Predicted hotplate temperature: ${hotplate_temp}°C\n";

=head2 Custom Parameters

  # Create predictor optimized for your specific system
  my $predictor = Milton::Predictor::LossyLPF->new(
    tau           => 35,
    'loss-factor' => 0.88
  );

=head2 Tuning Parameters

  # Tune parameters using historical data
  my $tuned_params = $predictor->tune($historical_samples, 
    threshold => 0.0005,  # More precise convergence
    parallel => 4         # Use 4 parallel processes
  );
  
  print "Tuned tau: $tuned_params->{tau}\n";
  print "Tuned loss-factor: $tuned_params->{'loss-factor'}\n";

=head1 THERMAL MODEL DETAILS

The LossyLPF predictor models the thermal system as a first-order system with losses:

=over

=item * **Heating Element**: The primary heat source with measured temperature.

=item * **Thermal Losses**: Accounted for by the loss factor

=item * **Hotplate**: The target whose temperature is being predicted.

=item * **Thermal Mass**: Modeled by the time constant, tau.

=item * **Rate of Heat Flow to Ambient Environment**: Modeled by the time constant, tau.

=back

The model assumes:
- Linear heat transfer relationships
- Constant thermal properties over the temperature range
- Negligible heat transfer to the environment (compared to element-to-hotplate transfer)

=head1 LIMITATIONS

=over

=item * Does not account for variation in effective thermal mass versus temperature

=item * Does not account for variation in effective thermal resistance versus temperature

=item * Requires current ambient temperature measurement

=back

=head1 SEE ALSO

=over

=item * L<Milton::Predictor> - Base predictor class

=item * L<Milton::Predictor::DoubleLPF> - An improved model that models losses to the ambient environment differently

=item * L<Milton::Predictor::BandedLPF> - An improved model that models variation in thermal properties across the operating temperature range

=item * L<Milton::Math::Util> - Mathematical utilities used for tuning

=item * L<Milton::Controller> - Controller classes that use this predictor

=back

=head1 AUTHOR

Brett Gersekowski

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Brett Gersekowski

This module is part of Milton - The Makeshift Melt Master! - a system for controlling solder reflow hotplates.

This software is licensed under an MIT licence. The full licence text is available in the LICENCE.md file distributed with this project.

=cut

sub new {
  my ($class, %options) = @_;

  my $self = $class->SUPER::new(%options);

  $self->{tau} //= 27;
  $self->{'loss-factor'} //= 0.925;

  return $self;
}

sub description {
  my ($self) = @_;
  return sprintf('LossyLPF(tau=%.3f, loss-factor=%.3f)', $self->{tau}, $self->{'loss-factor'});
}

sub predictTemperature {
  my ($self, $status) = @_;

  my $last_prediction = $self->{'last-prediction'};
  my $prediction;

  if (defined $last_prediction) {
    my $ambient = $status->{ambient};
    my $alpha = $status->{period} / ($status->{period} + $self->{tau});
    my $rel_temperature = ($status->{temperature} - $ambient) * $self->{'loss-factor'};
    $prediction = $ambient + $rel_temperature * $alpha + (1-$alpha) * ($last_prediction - $ambient);
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

sub tune {
  my ($self, $samples, %args) = @_;

  my $filtered = $self->filterSamples($samples);

  my $tuned = $self->_tune($filtered
                           , [ 'tau', 'loss-factor' ]
                           , [ [ 0, 100 ], [ 0.8, 1 ] ]
                           , 'lower-constraint' => [ 0, 0.8 ]
                           , 'upper-constraint' => [ undef, 1 ]
                           , threshold => 0.001
                           , %args
                           );
  
  return $tuned;
}

1;