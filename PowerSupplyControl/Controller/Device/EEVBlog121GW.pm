package PowerSupplyControl::Controller::Device::EEVBlog121GW;

use strict;
use warnings qw(all -uninitialized);
use AnyEvent;
use Carp;
use Readonly;
use PowerSupplyControl::ValueTools qw(hexToNumber);

use base qw(BLE::BlueToothCtl);

Readonly our $DEVICE_ADDRESS => qr/88:6B:0F:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}/;
Readonly our $INDICATION_UUID => 'e7add780-b042-4876-aae1-112855353cc1';
Readonly our $INDICATION_SERVICE => '121GW:/service0006/char0007';

=head1 NAME

PowerSupplyControl::Controller::Device::EEVBlog121GW - EEVBlog 121GW Multimeter Interface

=head1 SYNOPSIS

  use PowerSupplyControl::Controller::Device::EEVBlog121GW;
  
  my $meter = PowerSupplyControl::Controller::Device::EEVBlog121GW->new();
  
  $meter->connect() || die "Failed to connect to 121GW\n";

  $meter->startListening();

  ...

  $meter->getDisplayValue();
  $meter->getMode();
  $meter->getSubValue();
  
  ...
  
  $meter->disconnect();
  $meter = undef;

=head1 DESCRIPTION

This module provides an interface to the EEVBlog 121GW multimeter via Bluetooth Low Energy.
It connects to the device using BlueToothCtl and subscribes to indications containing
the current display data.

=cut

=head2 new(%options)

Create a new 121GW multimeter object.

=over

=item device-address

The Bluetooth address of the 121GW device. If not provided, the constructor will scan for the
first device it finds with a UUID matching the prefix 88:6B:0F.

=item indication-uuid

The UUID of the indication characteristic. Defaults to "e7add780-b042-4876-ae1-112855353cc1".

=item indication-service

The service name of the indication characteristic. Defaults to "service0006/char0007".

=item max-offset

When defined, this is the maximum different between successive measurements that will be
accepted. If the difference is greater than this value, then the measurement is rejected.

=back

=cut

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);

  if ($options{'device-address'}) {
    $self->connect(qr/$options{'device-address'}/);
  } else {
    $self->connect($DEVICE_ADDRESS);
  }

  croak 'Failed to connect to 121GW' unless $self->isConnected();

  my $uuid = $options{'indication-uuid'} || $INDICATION_UUID;
  my $service = $options{'indication-service'} || $INDICATION_SERVICE;

  $self->subscribe($uuid, $service)
    || croak "Failed to subscribe to indication characteristic $uuid";
  
  return $self;
}

sub deviceName {
  return 'EEVBlog 121GW';
}

sub setLogger {
  my ($self, $logger) = @_;
  $self->{logger} = $logger;
}

sub shutdown {
  my ($self) = @_;

  $self->stopListening;


  return $self;
}

=head2 startListening()

Start listening for indications from the device. This sets up an AnyEvent-based
event handler for processing incoming indication data.

=cut

sub startListening {
  my ($self) = @_;
  return unless $self->isConnected() && $self->isSubscribed();

  $self->send('notify on');
  
  # Clear the receive buffer of any junk that might be in it
  $self->clearInputBuffer;

  $self->{'read-buffer'} = [];
  $self->{'service-re'} = qr/\[$self->{attribute}\]> .*\r  (([0-9a-fA-F]{2} ){1,16}) /;

  $self->{watcher} = AnyEvent->io(fh => $self->{recv}
                                , poll => 'r'
                                , cb => sub {
                                    $self->receiveData();
                                    return;
                                  }
                                );
}

sub isListening {
  my ($self) = @_;
  return defined $self->{watcher};
}

sub listenNow {
  my ($self) = @_;

  return if $self->isListening();
  return if $self->{'cond-var'};
  $self->{'cond-var'} = AnyEvent->condvar;
  $self->startListening();
  $self->{'cond-var'}->recv;
  $self->stopListening();
  delete $self->{'cond-var'};

  return $self;
}

sub receiveData {
  my ($self) = @_;
  return unless $self->{recv};

  my $line = $self->{recv}->getline;
  chomp $line;
  print "line: $line\n" if $self->{debug};

  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

  if (my ($hex) = $line =~ $self->{'service-re'}) {
    $hex =~ s/^\s+//;
    $hex =~ s/\s+$//;
    my @bytes = split /\s+/, $hex;
    hexToNumber(@bytes);
    push @{$self->{'read-buffer'}}, @bytes;
  }

  $self->parseData;
}

Readonly my %MODES => ( 1 => 'VDC'
                      , 3 => 'mVDC'
                      , 4 => 'mVAC'
                      , 5 => 'Temp'
                      , 2 => 'VAC'
                      , 9 => 'Resistance'
                      , 10 => 'Continuity'
                      , 11 => 'Diode'
                      , 12 => 'Capacitance'
                      , 24 => 'mVADC'
                      , 15 => 'mVAAC'
                      , 22 => 'uADC'
                      , 13 => 'uAAC'
                      , 17 => 'uADC-BDOFF'
                      , 16 => 'uAAC-BDOFF'
                      , 21 => 'mADC-BDOFF'
                      , 20 => 'mAAC-BDOFF'
                      , 6 => 'Hertz'
                      , 7 => 'ms'
                      , 8 => '%'
                      , 0 => 'V-lowZ'
                      );

Readonly my %RANGES => ( '5:0' => 10
                       , '100:1' => 10
                       , '1:1' => 1000
                       , '21:0' => 100
                       );
sub parseData {
  my ($self) = @_;

  my $buf = $self->{'read-buffer'};
  print "parseData: ". scalar(@$buf). " bytes in buffer [ ". join(', ', @$buf). " ]\n" if $self->{debug};
  my $parseCount = 0;
  my $max_offset = $self->{'max-offset'};
  my $max_value = $self->{'max-value'};
  my $min_value = $self->{'min-value'};

  my $last_hot = $self->{'last-hot'};
  my $last_cold = $self->{'last-cold'};
  
  while (@$buf) {
    
    # Clear any leading data until we see a start of frame byte
    my $count = 0;
    while (@$buf && $buf->[0] != 0xf2) {
      shift @$buf;
      $count++;
    }
    warn "parseData: cleared $count bytes from buffer\n" if $count;

    if (@$buf >= 19) {
      my $mode = $buf->[5] & 0x3f;
      my $range = $buf->[6] & 0x0f;
      my $temp_scale = $buf->[6] & 0x30;
      $temp_scale = $temp_scale == 0x20 ? 'celsius' : ($temp_scale == 0x10 ? 'fahrenheit' : '');
      my $neg = $buf->[6] & 0x40;
      my $ofl = $buf->[6] & 0x80;
      my $main_value = (($buf->[5] & 0xc0) << 10) | ($buf->[7] << 8) | $buf->[8];
      $main_value = $ofl ? undef : ($neg ? -$main_value : $main_value);

      my $sub_mode = $buf->[9];
      my $sub_range = $buf->[10] & 0x0f;
      my $sub_neg = $buf->[10] & 0x40;
      my $sub_ofl = $buf->[10] & 0x80;
      my $sub_value = ($buf->[11] << 8) | $buf->[12];
      $sub_value = $sub_ofl ? undef : ($sub_neg ? -$sub_value : $sub_value);

      my $rangekey = "$mode:$range";
      if (exists $MODES{$mode}) {
        $mode = $MODES{$mode};
      }

      if (exists $RANGES{$rangekey}) {
        $main_value = $main_value / $RANGES{$rangekey};
      }

      $rangekey = "$sub_mode:$sub_range";
      if (exists $RANGES{$rangekey}) {
        $sub_value = $sub_value / $RANGES{$rangekey};
      }

      # Sometimes we read wild data, so check against some sane limits if configured
      my $legal = 1;
      if ($max_offset) {
        if (defined $last_hot) {
          $legal = abs($main_value - $last_hot) <= $max_offset;
          warn "parseData: rejected measurement: hot=$main_value, last_hot=$last_hot, max-offset=$max_offset\n" unless $legal;
        }
        if (defined $last_cold) {
          $legal = abs($sub_value - $last_cold) <= $max_offset;
          warn "parseData: rejected measurement: cold=$sub_value, last_cold=$last_cold, max-offset=$max_offset\n" unless $legal;
        }
      }
      if ($legal && $max_value) {
        if ($main_value > $max_value) {
          warn "parseData: rejected measurement: main_value=$main_value, max_value=$max_value\n";
          $legal = 0;
        }
        if ($sub_value > $max_value) {
          warn "parseData: rejected measurement: sub_value=$sub_value, max_value=$max_value\n";
          $legal = 0;
        }
      }
      if ($legal && $min_value) {
        if ($main_value < $min_value) {
          warn "parseData: rejected measurement: main_value=$main_value, min_value=$min_value\n";
          $legal = 0;
        }
        if ($sub_value < $min_value) {
          warn "parseData: rejected measurement: sub_value=$sub_value, min_value=$min_value\n";
          $legal = 0;
        }
      }
      # Check the XOR checksum byte
      my $checksum = 0;
      for (my $i=0; $i<19; $i++) {
        $checksum ^= $buf->[$i];
      }
      if ($checksum != 0) {
        warn "parseData: rejected measurement: checksum=$checksum, expected=0\n";
        $legal = 0;
      }

      if ($legal) {
        $self->{'display-value'} = $main_value;
        $self->{'sub-value'} = $sub_value;
        $self->{'mode'} = $mode;
        $self->{'temp-scale'} = $temp_scale;
        $self->{'sub-mode'} = $sub_mode;
        $self->{'range'} = $range;
        $self->{'sub-range'} = $sub_range;
        $last_hot = $main_value;
        $last_cold = $sub_value;
        $parseCount++;
      }

      splice @$buf, 0, 19;
    } else {
      last;
    }
  }

  if ($parseCount > 0 && exists $self->{'cond-var'}) {
    $self->{'cond-var'}->send;
  }

  $self->{'last-hot'} = $last_hot;
  $self->{'last-cold'} = $last_cold;

  return $self;
}

=head2 stopListening()

Stop listening for indications from the device.

=cut

sub stopListening {
  my ($self) = @_;
  return unless $self->isConnected() && $self->isListening();
  $self->receiveData();
  $self->send('notify off');
  $self->{watcher} = undef;
}

=head2 getDisplayValue()

Get the most recent display value from the device.

=over

=item Return Value

Returns the parsed display value as a string, or undef if no value has been received.

=back

=cut

sub getDisplayValue {
  my ($self) = @_;
  return $self->{'display-value'};
}

=head2 getMode()

Get the most recent mode from the device.

=over

=item Return Value

Returns the most recent mode as a string, or undef if no value has been received.

=cut

sub getMode {
  my ($self) = @_;
  return $self->{'mode'};
}

=head2 getSubValue()

Get the most recent sub-value from the device.

=cut

sub getSubValue {
  my ($self) = @_;
  return $self->{'sub-value'};
}

=head2 getSubMode()

Get the most recent sub-mode from the device.

=cut

sub getSubMode {
  my ($self) = @_;
  return $self->{'sub-mode'};
}

=head2 getTempScale()

Get the most recent temperature scale from the device.

=cut

sub getTempScale {
  my ($self) = @_;
  return $self->{'temp-scale'};
}

=head2 getTemperature

Get the most recent temperature from the device in celsius.

=over

=item Return Value

If the multimeter is not in temperature mode, then returns undef.
Temperatures are always returned in celsius.
In a scalar context, returns the latest hot-junction temperature.
In a list context, returns the latest hot-junction and cold junction temperatures.

=back

=cut

sub getTemperature {
  my ($self) = @_;

  if ($self->{'mode'} eq 'Temp') {
    my $hot = $self->{'display-value'};
    my $cold = $self->{'sub-value'};

    if ($self->{'temp-scale'} eq 'fahrenheit') {
      $hot = ($hot - 32) * 5/9;
      $cold = ($cold - 32) * 5/9;
    }

    if (wantarray) {
      return ($hot, $cold);
    }
    return $hot;
  }

  return;
}

1; 