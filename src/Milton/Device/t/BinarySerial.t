#!/usr/bin/perl

use lib '.';
use strict;
use warnings qw(all -uninitialized);
use Test2::V0;
use Milton::Device::BinarySerial;

# ---------------------------------------------------------------------------
# Mock SerialPortHelper: provides canned data when READ is called.
# get_serial_port returns an object with READ($buffer, $offset, $max) that
# writes canned bytes into the buffer at offset and returns count.
# ---------------------------------------------------------------------------
{
  package MockSerialPort;
  sub new {
    my ($class, $canned_data) = @_;
    bless { canned_data => $canned_data // '' }, $class;
  }
  sub read {
    my ($self, $max) = @_;
    my $data = $self->{canned_data} // '';
    my $len = length($data);
    # @_ elements are aliases; write at offset so caller's buffer is updated
    no warnings 'substr';
    my $chars = substr($data, 0, $max);
    $self->{canned_data} = substr($data, $max);
    
    return (length($chars), $chars);
  }
}

{
  package MockSerialPortHelper;
  sub new {
    my ($class, $canned_data) = @_;
    bless {
      serial => MockSerialPort->new($canned_data),
      canned_data => $canned_data // '',
    }, $class;
  }
  sub get_serial_port { $_[0]->{serial} }
  sub get_fileno      { 0 }
  sub disconnect     { 1 }
}

# ---------------------------------------------------------------------------
# Helper: create BinarySerial with optional mock helper and canned data.
# If canned_data is provided, sets helper to mock and calls _read_buffer once.
# ---------------------------------------------------------------------------
sub make_device {
  my (%opts) = @_;
  my $device = Milton::Device::BinarySerial->new(
    device => $opts{device} // '/dev/ttyTEST',
    (exists $opts{handler} ? (handler => $opts{handler}) : ()),
  );
  if (exists $opts{canned_data}) {
    $device->{helper} = MockSerialPortHelper->new($opts{canned_data});
    $device->_read_buffer;
  }
  return $device;
}

# ---------------------------------------------------------------------------
# Helper: set buffer state directly (for tests that don't use _read_buffer)
# ---------------------------------------------------------------------------
sub set_buffer {
  my ($device, $str, $pos) = @_;
  $device->{buffer} = $str;
  $device->{buflen} = length($str);
  $device->{bufpos} = $pos // 0;
}

# ---------------------------------------------------------------------------
# lookfor
# ---------------------------------------------------------------------------
subtest 'lookfor' => sub {
  my $dev = make_device();
  set_buffer($dev, 'ABCDEF', 0);

  is($dev->bufferLength, 6, 'Initial buffer length');
  ok($dev->lookfor('D'), 'lookfor finds char in buffer');
  is($dev->bufferLength, 3, 'bufferLength after lookfor');
  is($dev->readChars(2), 'DE', 'readChars after lookfor');

  set_buffer($dev, 'ABCDEF', 0);
  is($dev->bufferLength, 6, 'bufferLength after set_buffer');
  ok(!$dev->lookfor('X'), 'lookfor returns false when char not present');
  is($dev->bufferLength, 0, 'bufferLength after lookfor failed');
  is($dev->readChars(2), '', 'readChars after lookfor failed');

  set_buffer($dev, 'ABCDEF', 0);
  ok($dev->lookfor('A'), 'lookfor finds char at start');
  is($dev->bufferLength, 6, 'bufferLength after lookfor at start');
  is($dev->readChars(2), 'AB', 'readChars after lookfor at start');
  ok($dev->lookfor('C'), 'lookfor finds char at current position');
  is($dev->bufferLength, 4, 'bufferLength after lookfor at current position');
  is($dev->readChars(2), 'CD', 'readChars after lookfor at current position');  
  ok($dev->lookfor('F'), 'lookfor finds char at end');
  is($dev->bufferLength, 1, 'bufferLength after lookfor at end');
  is($dev->readChars(2), 'F', 'readChars after lookfor at end');

  set_buffer($dev, 'AB', 0);
  ok(!$dev->lookfor('C'), 'lookfor drains buffer when not found');
  is($dev->bufferLength, 0, 'bufferLength after lookfor failed');
  is($dev->{buffer}, '', 'buffer drained');
  is($dev->{bufpos}, 0, 'bufpos reset');
  is($dev->{buflen}, 0, 'buflen reset');
};

# ---------------------------------------------------------------------------
# readChars
# ---------------------------------------------------------------------------
subtest 'readChars' => sub {
  my $dev = make_device();
  set_buffer($dev, 'HELLO', 0);

  is($dev->readChars(2), 'HE', 'readChars returns requested substring');
  is($dev->bufferLength, 3, 'bufferLength after readChars');
  is($dev->readChars(3), 'LLO', 'readChars remainder');
  is($dev->bufferLength, 0, 'bufferLength after readChars remainder');
  is($dev->readChars(2), '', 'readChars after readChars remainder');
};

# ---------------------------------------------------------------------------
# truncateBuffer
# ---------------------------------------------------------------------------
subtest 'truncateBuffer' => sub {
  my $dev = make_device();
  set_buffer($dev, 'HELLO', 2);

  $dev->truncateBuffer;
  is($dev->{buffer}, 'LLO', 'truncateBuffer keeps unconsumed');
  is($dev->{buflen}, 3, 'buflen updated');
  is($dev->{bufpos}, 0, 'bufpos reset to 0');
};

# ---------------------------------------------------------------------------
# drainBuffer
# ---------------------------------------------------------------------------
subtest 'drainBuffer' => sub {
  my $dev = make_device();
  set_buffer($dev, 'HELLO', 2);

  $dev->drainBuffer;
  is($dev->{buffer}, '', 'drainBuffer clears buffer');
  is($dev->{buflen}, 0, 'buflen zero');
  is($dev->{bufpos}, 0, 'bufpos zero');
};

# ---------------------------------------------------------------------------
# readByte
# ---------------------------------------------------------------------------
subtest 'readByte' => sub {
  my $dev = make_device();
  set_buffer($dev, 'AB', 0);

  is($dev->bufferLength, 2, 'bufferLength after set_buffer');
  is($dev->readByte, ord('A'), 'readByte first byte');
  is($dev->bufferLength, 1, 'bufferLength after readByte');
  is($dev->readByte, ord('B'), 'readByte second byte');
  is($dev->bufferLength, 0, 'bufferLength after readByte');
  is($dev->{buffer}, '', 'buffer cleared after reading to the end');
  is($dev->{buflen}, 0, 'buflen zeroed after reading to the end');
  is($dev->{bufpos}, 0, 'bufpos zeroed after reading to the end');
  is($dev->readByte, undef, 'readByte returns undef when buffer is empty');

  set_buffer($dev, 'X', 0);
  is($dev->readByte, ord('X'), 'readByte single byte');
  is($dev->{buffer}, '', 'buffer drained after readByte exhausts');
  is($dev->readByte, undef, 'readByte undef after last byte');
};

# ---------------------------------------------------------------------------
# skipChars
# ---------------------------------------------------------------------------
subtest 'skipChars' => sub {
  my $dev = make_device();
  set_buffer($dev, 'HELLO', 0);

  $dev->skipChars(2);
  is($dev->bufferLength, 3, 'bufferLength after skipChars');
  is($dev->readChars(2), 'LL', 'readChars after skipChars');

  $dev->skipChars(1);
  is($dev->bufferLength, 0, 'bufferLength after skipChars');
  is($dev->readChars(2), '', 'readChars after skipChars');

  set_buffer($dev, 'WORLD', 3);
  $dev->skipChars(2);
  is($dev->{buffer}, '', 'skipChars to end clears buffer');
  is($dev->bufferLength, 0, 'bufferLength after skipChars to end');
  is($dev->readChars(2), '', 'readChars after skipChars to end');

  set_buffer($dev, '12345', 3);
  $dev->skipChars(10);
  is($dev->{buffer}, '', 'skipChars past end clears buffer');
  is($dev->bufferLength, 0, 'bufferLength after skipChars past end');
  is($dev->readChars(2), '', 'readChars after skipChars past end');
};

# ---------------------------------------------------------------------------
# Integration: mock helper + _read_buffer, then buffer methods
# ---------------------------------------------------------------------------
subtest 'mock helper and _read_buffer' => sub {
  my $dev = make_device(canned_data => 'PROMPT:0:Enter value');

  is($dev->{buffer}, 'PROMPT:0:Enter value', '_read_buffer populated from mock');
  is($dev->{buflen}, length('PROMPT:0:Enter value'), 'buflen set');
  is($dev->{bufpos}, 0, 'bufpos set to 0');

};

done_testing;
