package Milton::Device::Brymen::BM2257;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Device::BinarySerial);

use Time::HiRes qw(sleep);

use Device::SerialPort;
use Readonly;

sub new {
  my ($class, %config) = @_;

  my $self = $class->SUPER::new(%config);

  return $self;
}

sub deviceName {
  return 'Brymen BM2257 Multimeter';
}

sub identify {
  my ($self, $helper) = @_;
  my $packet = undef;

  my $i = 3;
  while ($i > 0) {
    if ($self->readBuffer($helper) > 0) {
      $packet = $self->receiveData($helper);
      return if $packet;
    }

    $i--;
    sleep 0.5 if $i;
  }

  return "BM2257 Multimeter not found on $helper->{'connected-device'}"
}

Readonly my $PACKET_START => chr(0b00001010);
sub receiveData {
  my $self = shift;
  my $helper = shift // $self->{helper};

  return if !$helper;

  return if !$self->lookfor($PACKET_START);
  my $packet = undef;

  PACKET: while ($self->bufferLength > 15) {
    $self->skipChars(1);

    my @bytes = ();
    my $i = 0;
    BYTE: while (@bytes < 14 && (my $b = $self->readByte)) {
      $i++;
      #printf "byte[%02d]: %02x (%08b)\n", scalar(@bytes), $b, $b;
      my $idx = ($b & 0xf0) >> 4;

      if ($i != $idx) {
        #print "next PACKET (i=$i, idx=$idx)\n";
        next PACKET;
      }

      push @bytes, $b & 0x0f;
    }

    # Combine pairs of 4 bit nibbles into complete 8-bit bytes
    for (my $i = 0; $i < @bytes; $i += 2) {
      my $j = $i >> 1;
      $bytes[$j] = $bytes[$i] | $bytes[$i + 1] << 4;
    }
    splice @bytes, 7;
    $packet = $self->parsePacket(\@bytes);
    if ($packet) {
      $self->{packet} = $packet;
      $self->processPacket($packet);
    }

    last PACKET if !$self->lookfor($PACKET_START);
  }

  return $packet;
}

Readonly my @FORMATS => qw( %s%s%s%s%s %s%s.%s%s%s %s%s%s.%s%s %s%s%s%s.%s );

Readonly my $MASK_BEEP => 0x800000;
Readonly my $MASK_BATTERY => 0x400000;
Readonly my $MASK_LOZ => 0x200000;
Readonly my $MASK_VFD => 0x100000;
Readonly my $MASK_AUTO => 0x080000;
Readonly my $MASK_DC => 0x040000;
Readonly my $MASK_AC => 0x020000;
Readonly my $MASK_DELTA => 0x010000;

Readonly my $MASK_C => 0x8000;
Readonly my $MASK_OHMS => 0x4000;
Readonly my $MASK_HZ => 0x2000;
Readonly my $MASK_N => 0x1000;
Readonly my $MASK_H => 0x0800;
Readonly my $MASK_DBM => 0x0400;
Readonly my $MASK_M => 0x0200;
Readonly my $MASK_K => 0x0100;

Readonly my $MASK_MIN => 0x80;
Readonly my $MASK_V => 0x40;
Readonly my $MASK_A => 0x20;
Readonly my $MASK_DIODE => 0x10;
Readonly my $MASK_MAX => 0x08;
Readonly my $MASK_F => 0x04;
Readonly my $MASK_MU => 0x02;
Readonly my $MASK_LC_M => 0x01;

# Mask representing valid flags that can be set when in temperature measurement mode
Readonly my $MASK_TEMPERATURE => $MASK_BATTERY | $MASK_MAX | $MASK_MIN;

sub parsePacket {
  my ($self, $packet) = @_;

  #printf "parsePacket: [ %02x %02x %02x %02x %02x %02x %02x ]\n", @$packet;
  my $digits = [ map { __parse_digit($_) } @{$packet}[1..4] ];
  if (@$digits < 4 || !defined($digits->[0]) || !defined($digits->[1]) || !defined($digits->[2]) || !defined($digits->[3])) {
    return;
  }

  my $decimal = $packet->[2] & 1 ? 1 : ($packet->[3] & 1 ? 2 : ($packet->[4] & 1 ? 3 : 0));
  my $negative = $packet->[1] & 1;

  my $display = sprintf($FORMATS[$decimal]
                      , $negative ? '-' : ''
                      , @$digits
                      );

  my $flags = $packet->[0] << 16 | $packet->[5] << 8 | $packet->[6];

  my $result = { rawdigits => [ $packet->[1], $packet->[2], $packet->[3], $packet->[4] ]
               , digits => $digits
               , decimal => $decimal
               , negative => $negative
               , display => $display
               , flags => $flags
               , auto => $flags & $MASK_AUTO
               , DC => $flags & $MASK_DC
               , AC => $flags & $MASK_AC
               , delta => $flags & $MASK_DELTA
               , beep => $flags & $MASK_BEEP
               , battery => $flags & $MASK_BATTERY
               , LoZ => $flags & $MASK_LOZ
               , VFD => $flags & $MASK_VFD
               , H => $flags & $MASK_H
               , dBm => $flags & $MASK_DBM
               , M => $flags & $MASK_M
               , k => $flags & $MASK_K
               , C => $flags & $MASK_C
               , ohms => $flags & $MASK_OHMS
               , Hz => $flags & $MASK_HZ
               , n => $flags & $MASK_N
               , max => $flags & $MASK_MAX
               , F => $flags & $MASK_F
               , mu => $flags & $MASK_MU
               , m => $flags & $MASK_LC_M
               , min => $flags & $MASK_MIN
               , V => $flags & $MASK_V
               , A => $flags & $MASK_A
               , diode => $flags & $MASK_DIODE
               };
}

sub processPacket {
  my ($self, $packet) = @_;

  my $display = $packet->{display};
  my $flags = $packet->{flags};

  delete $self->{volts};
  delete $self->{amps};
  delete $self->{ohms};
  delete $self->{hz};
  delete $self->{temperature};

  if (($flags & $MASK_TEMPERATURE) == 0 && $display =~ /^(-?\d+(\.\d+)?)([CF])$/) {
    if ($3 eq 'C') {
      $self->setTemperature($1 + 0);
    } else {
      $self->setFahrenheit($1 + 0);
    }
    return;
  }

  my $value;
  if ($packet->{m}) {
    $value = $display / 1000;
  } elsif ($packet->{k}) {
    $value = $display * 1000;
  } elsif ($packet->{mu}) {
    $value = $display / 1000000;
  } elsif ($packet->{n}) {
    $value = $display / 1000000000;
  } elsif ($packet->{M}) {
    $value = $display * 1000000;
  } else {
    $value = $display + 0;
  }

  if ($packet->{V}) {
    $self->{volts} = $value;
  } elsif ($packet->{A}) {
    $self->{amps} = $value;
  } elsif ($packet->{ohms}) {
    $self->{ohms} = $value;
  } elsif ($packet->{hz}) {
    $self->{hz} = $value;
  }
}

sub setTemperature {
  my ($self, $temperature) = @_;
  my $rc = $self->{temperature};

  $self->{temperature} = $temperature;

  return $rc;
}

sub setFahrenheit {
  my ($self, $fahrenheit) = @_;
  
  my $celsius = $self->setTemperature(($fahrenheit - 32) * 5 / 9);

  return $celsius * 9 / 5 + 32;
}

sub __parse_digit {
  my ($raw) = @_;

  if ($raw eq '' || !defined($raw)) {
    return;
  }

  my $masked = $raw & 0b11111110;

  return '0' if $masked == 0b10111110;
  return '1' if $masked == 0b10100000;
  return '2' if $masked == 0b11011010;
  return '3' if $masked == 0b11111000;
  return '4' if $masked == 0b11100100;
  return '5' if $masked == 0b01111100;
  return '6' if $masked == 0b01111110;
  return '7' if $masked == 0b10101000;
  return '8' if $masked == 0b11111110;
  return '9' if $masked == 0b11111100;
  return 'C' if $masked == 0b00011110;
  return 'F' if $masked == 0b01001110;

  #printf "parse_digit failed for %02x (%08b)\n", $masked, $masked;

  return;
}

1;