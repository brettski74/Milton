package PowerSupplyControl::t::MockInterface;

use strict;
use warnings qw(all -uninitialized);
use base qw(PowerSupplyControl::Interface);
use Carp;
use Clone qw(clone);

=head1 NAME

PowerSupplyControl::t::MockInterface - Mock Interface for testing

=head1 DESCRIPTION

A mock interface that returns predictable data for testing.
Can be initialized with default data and updated via setMockData.

=cut

sub new {
  my ($class, $config) = @_;
  
  # Create a default config if none provided
  # Minimums shoudl always be greater than zero. We need current flowing to get resistance measurements which are in turn required for estimating hotplate temperature.
  # Measurable current - I'd like that to be different from the minimum current so that it's distinguishable in tests.
  # STOP CHANGING THESE VALUES FROM THE VALUES I PROVIDED. Fix the tests to use these values and I really fail to see how using a different number here is going to fix an error from trying to use 0 as a hash reference.
  $config ||= {
    voltage => { minimum => 1, maximum => 30 },
    current => { minimum => 0.1, maximum => 10, measurable => 1 },
    power => { minimum => 10, maximum => 120 }
  };
  
  $config->{'poll-count'} //= 0;
  $config->{'mock-on-state'} //= 0;
  $config->{'mock-voltage-setpoint'} //= 0;
  $config->{'mock-current-setpoint'} //= 0;
  $config->{'mock-output-voltage'} //= 0;
  $config->{'mock-output-current'} //= 0;

  my $self = $class->SUPER::new($config);
  
  # Initialize with default data
  $self->setMockData([
    ['id', 'voltage', 'current', 'power', 'temperature'],
    [1, 12.5, 2.1, 26.25, 85.2]
  ]) unless $self->{rows};
  
  return $self;
}

=head2 setMockData($data)

Set the mock data for this interface. Replaces any existing mock data.

=over

=item $data

Array reference where first element is an array of column names, 
and subsequent elements are arrays of values.

=back

=cut

sub setMockData {
  my ($self, $data) = @_;
  
  croak "Mock data must be an array reference" unless ref($data) eq 'ARRAY';
  croak "Mock data must have at least column names and one data row" unless @$data >= 2;
  
  my $keys = shift @$data;
  my $rows = [];
  
  # Convert data rows to hashes
  foreach my $vals (@$data) {
    my $row = {};
    @$row{@$keys} = @$vals;
      
    push @$rows, $row;
  }
    
  $self->{rows} = $rows;
  $self->{'current-row'} = 0;
  
  return;
}

=head2 setMockOutput($voltage, $current, $on_state)

Set the mock output values for testing.

=over

=item $voltage

The output voltage to simulate.

=item $current

The output current to simulate.

=item $on_state

The output on/off state to simulate.

=back

=cut

sub setMockOutput {
  my ($self, $voltage, $current, $on_state) = @_;
  $self->{'mock-output-voltage'} = $voltage;
  $self->{'mock-output-current'} = $current;
  $self->{'mock-on-state'} = $on_state;

  # Remove existing data rows otherwise they will override this.
  delete $self->{rows};
  delete $self->{'current-row'};

  return $self;
}

# Override the private methods to provide mock implementations

sub _connect {
  my ($self) = @_;
  return (
    $self->{'mock-voltage-setpoint'},  # vset
    $self->{'mock-current-setpoint'},  # iset
    $self->{'mock-on-state'},          # on
    $self->{'mock-output-voltage'},    # vout
    $self->{'mock-output-current'}     # iout
  );
}

sub _disconnect {
  my ($self) = @_;
  # Mock disconnect - just return
  return;
}

sub _poll {
  my ($self) = @_;
  $self->{poll_count}++;
  
  # Get current data row if available
  if ($self->{rows} && @{$self->{rows}} > 0) {
    my $row = $self->{rows}->[$self->{'current-row'}];
    $self->{'mock-output-voltage'} = $row->{voltage} || 0;
    $self->{'mock-output-current'} = $row->{current} || 0;
      
    # Move to next row, wrapping around
    $self->{'current-row'} = ($self->{'current-row'} + 1) % @{$self->{rows}};
  }
  
  return ($self->{'mock-output-voltage'}, $self->{'mock-output-current'}, $self->{'mock-on-state'});
}

sub setResult {
  my ($self, $type, @result) = @_;

  my $key = "set-$type-result";

  if (@result) {
    $self->{$key} = \@result;
  } else {
    delete $self->{$key};
  }

  return;
}

sub _setVoltage {
  my ($self, $voltage, $recommendedCurrent) = @_;

  $self->{'mock-voltage-setpoint'} = $voltage;

  my @rc;
  if (exists $self->{'set-voltage-result'}) {
    @rc = @{$self->{'set-voltage-result'}};
  }

  if (!@rc) {
    return (1);
  }

  if ($rc[2] < 0) {
    $rc[2] = $recommendedCurrent;
  }

  return @rc;
}

sub _setCurrent {
  my ($self, $current, $recommendedVoltage) = @_;

  $self->{'mock-current-setpoint'} = $current;

  my @rc;
  if (exists $self->{'set-current-result'}) {
    @rc = @{$self->{'set-current-result'}};
  }

  if (!@rc) {
    return (1);
  }

  if ($rc[2] < 0) {
    $rc[2] = $recommendedVoltage;
  }

  return @rc;
}

sub _on {
  my ($self, $state) = @_;

  $self->{'mock-on-state'} = $state;

  if (exists $self->{'set-on-state-result'}) {
    return $self->{'set-on-state-result'}->[0];
  }

  return 1;
}

# Note: We do NOT override public methods - we want to test the base Interface class methods

# Helper methods for setting limits in tests
sub setPowerLimits {
  my ($self, $min_power, $max_power) = @_;
  $self->{power}->{minimum} = $min_power;
  $self->{power}->{maximum} = $max_power;
  return $self;
}

sub setVoltageLimits {
  my ($self, $min_voltage, $max_voltage) = @_;
  $self->{voltage}->{minimum} = $min_voltage;
  $self->{voltage}->{maximum} = $max_voltage;
  return $self;
}

sub setCurrentLimits {
  my ($self, $min_current, $max_current) = @_;
  $self->{current}->{minimum} = $min_current;
  $self->{current}->{maximum} = $max_current;
  return $self;
}

1; 