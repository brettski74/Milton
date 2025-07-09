package PowerSupplyControl::t::MockInterface;

use strict;
use warnings;
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
    my ($class) = @_;
    my $self = $class->SUPER::new({});
    $self->{poll_count} = 0;
    
    # Initialize with default data
    $self->setMockData([
        ['id', 'voltage', 'current', 'power', 'temperature'],
        [1, 12.5, 2.1, 26.25, 85.2]
    ]);
    
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
    $self->{current} = 0;
    
    return;
}

sub poll {
    my ($self) = @_;
    $self->{poll_count}++;
    
    # Get current data row
    my $row_data = clone $self->{rows}->[$self->{current}];
    
    # Move to next row, wrapping around
    $self->{current} = ($self->{current} + 1) % @{$self->{rows}};
    
    return $row_data;
}

sub setVoltage { return; }
sub setCurrent { return; }
sub setPower { return; }
sub shutdown { return; }

sub getMinimumCurrent {
  my ($self) = @_;
  return $self->{current}->{minimum} // 0.1;
}

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