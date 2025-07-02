package PowerSupplyControl::Interface::ReplayInterface;

use strict;
use warnings;
use base qw(PowerSupplyControl::Interface);
use Text::CSV;
use Path::Tiny;
use Carp;

=head1 NAME

PowerSupplyControl::Interface::ReplayInterface - Replay hotplate state from CSV file

=head1 SYNOPSIS

    my $interface = PowerSupplyControl::Interface::ReplayInterface->new({
        filename => 'replay_data.csv'
    });
    
    my $status = $interface->poll;
    
    # Setter methods do nothing in replay mode
    $interface->setPower($status, 100);
    $interface->setVoltage(12.0);
    $interface->setCurrent(5.0);

=head1 DESCRIPTION

ReplayInterface reads hotplate state information from a CSV file for testing and
replay purposes. The first row of the CSV file should contain the key names for
each column. Subsequent rows contain the state data.

Setter methods do nothing in replay mode. Getter methods return values from the
last poll operation.

=head1 CONSTRUCTOR

=head2 new($config)

Create a new ReplayInterface object.

=over

=item $config

A hash reference containing configuration options:

=over

=item filename

The path to the CSV file containing the replay data.

=back

=back

=cut

sub new {
    my ($class, $config) = @_;
    
    my $self = $class->SUPER::new($config);
    
    # Initialize CSV parser
    $self->{csv} = Text::CSV->new({
        binary => 1,
        auto_diag => 1,
    });
    
    $self->setFilename($self->{filename}) if $self->{filename};
    
    return $self;
}

=head2 setFilename($filename)

Set the CSV filename and load the file for reading.

=over

=item $filename

The path to the CSV file containing the replay data.

=back

=cut

sub setFilename {
    my ($self, $filename) = @_;
    
    croak "filename is required" unless $filename;
    
    $self->{filename} = $filename;
    
    # Load and parse the CSV file
    $self->_load_csv_file();
    
    return;
}

=head1 METHODS

=head2 poll

Read the next row from the CSV file and return the status data.

=over

=item Return Value

A hash reference containing the current status information from the CSV file.
Returns undef if no more data is available.

=back

=cut

sub poll {
    my ($self) = @_;
    
    
    # Auto-reopen file if needed (e.g., after shutdown)
    if (!defined $self->{fh}) {
      croak "No filename specified. Call setFilename() first." unless $self->{filename};
      $self->{fh} = path($self->{filename})->openr();
      # Skip header row
      $self->{csv}->getline($self->{fh});
    }
    
    # Read next row from CSV
    my $row = $self->{csv}->getline($self->{fh});
    
    if (!$row) {
      # End of file reached
      return undef;
    }
    
    # Create status hash from column names and values
    my $status = {};
    for my $i (0 .. $#{$self->{column_names}}) {
        my $key = $self->{column_names}->[$i];
        my $value = $row->[$i];
        
        $status->{$key} = $value;
    }
    
    return $status;
}

=head2 setVoltage($voltage)

Set the output voltage (does nothing in replay mode).

=over

=item $voltage

The voltage to set (ignored in replay mode).

=back

=cut

sub setVoltage {
    return;
}

=head2 setCurrent($current)

Set the output current (does nothing in replay mode).

=over

=item $current

The current to set (ignored in replay mode).

=back

=cut

sub setCurrent {
    return;
}

=head2 setPower($power, $resistance)

Set the output power (does nothing in replay mode).

=over

=item $power

The power to set (ignored in replay mode).

=item $resistance

The load resistance (ignored in replay mode).

=back

=cut

sub setPower {
    return;
}

=head2 shutdown

Shutdown the interface (does nothing in replay mode).

=cut

sub shutdown {
    my ($self) = @_;
    
    # Close the CSV file
    if ($self->{fh}) {
        close $self->{fh};
        $self->{fh} = undef;
    }
    
    return;
}

=head2 reset

Reset the replay to the beginning of the file.

=cut

sub reset {
    my ($self) = @_;
    
    croak "No filename specified. Call setFilename() first." unless $self->{filename};
    
    # Close current file handle
    if ($self->{fh}) {
        close $self->{fh};
    }
    
    # Reopen the file
    $self->{fh} = path($self->{filename})->openr();
    
    # Skip header row
    $self->{csv}->getline($self->{fh});
    
    return;
}

=head1 PRIVATE METHODS

=head2 _load_csv_file

Load and parse the CSV file, extracting column names from the first row.

=cut

sub _load_csv_file {
    my ($self) = @_;
    
    # Open the CSV file
    $self->{fh} = path($self->{filename})->openr()
        or croak "Cannot open CSV file: $self->{filename}";
    
    # Read header row to get column names
    my $header = $self->{csv}->getline($self->{fh});
    croak "CSV file is empty or has no header" unless $header;
    
    $self->{column_names} = $header;
    
    return;
}

1; 