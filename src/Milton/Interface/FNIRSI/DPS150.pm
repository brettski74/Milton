
  package Milton::Interface::FNIRSI::DPS150;

use strict;
use warnings qw(all -uninitialized);
use List::Util qw(sum);
use Readonly;
use Device::SerialPort;
use Time::HiRes qw(time sleep);

use base qw(Milton::Interface::SerialPort);

Readonly my $HEADER_REQUEST => 0xf1;
Readonly my $HEADER_RESPONSE => 0xf0;
Readonly my $CMD_READ_DEVICE_DATA => 0xa1;
Readonly my $CMD_SET_DEVICE_DATA => 0xb1;
Readonly my $CMD_DEVICE_CONNECT => 0xc1;
Readonly my $CMD_FIRMWARE_UPGRADE => 0xc0;

Readonly my $REG_V_INPUT => 0xc0;
Readonly my $REG_V_SETP  => 0xc1;
Readonly my $REG_I_SETP  => 0xc2;
Readonly my $REG_ALL_OUTPUT => 0xc3;
Readonly my $REG_TEMPERATURE => 0xc4;
Readonly my $REG_OUTPUT_ENABLE => 0xdb;
Readonly my $REG_MAXIMUM_VOLTAGE => 0xe2;
Readonly my $REG_MAXIMUM_CURRENT => 0xe3;
Readonly my $REG_METERING_OUTPUT_CAPACITY => 0xd9;
Readonly my $REG_METERING_OUTPUT_ENERGY => 0xda;
Readonly my $REG_OUTPUT_MODE => 0xdd;

sub parseSingleFloat {
  my ($self, $data) = @_;
  my ($float) = unpack('f<', $data);
  $self->{float} = $float;
  return $float;
}

sub parseMultipleFloats {
  my ($self, $data) = @_;
  my @floats = unpack('f<*', $data);
  $self->{floats} = \@floats;
  return \@floats;
}

sub parseUint8_t {
  my ($self, $data) = @_;
  my ($uint8_t) = unpack('C', $data);
  $self->{uint8_t} = $uint8_t;
  return $uint8_t;
}

Readonly my %CMD_MAP => ( $CMD_READ_DEVICE_DATA => 'Read Device Data'
                        , $CMD_SET_DEVICE_DATA  => 'Set Device Data'
                        , $CMD_DEVICE_CONNECT   => 'Device Connect'
                        , $CMD_FIRMWARE_UPGRADE => 'Firmware Upgrade'
                        );

Readonly my %REG_MAP => ( $REG_V_INPUT =>       { name => 'Input Voltage',    fn => \&parseSingleFloat    }
                        , $REG_V_SETP =>        { name => 'Voltage Setpoint', fn => \&parseSingleFloat    }
                        , $REG_I_SETP =>        { name => 'Current Setpoint', fn => \&parseSingleFloat    }
                        , $REG_ALL_OUTPUT =>    { name => 'All Output',       fn => \&parseMultipleFloats }
                        , $REG_TEMPERATURE =>   { name => 'Temperature',      fn => \&parseSingleFloat    }
                        , $REG_MAXIMUM_VOLTAGE => { name => 'Maximum Voltage', fn => \&parseSingleFloat    }
                        , $REG_MAXIMUM_CURRENT => { name => 'Maximum Current', fn => \&parseSingleFloat    }
                        , $REG_METERING_OUTPUT_CAPACITY => { name => 'Metering Output Capacity', fn => \&parseSingleFloat    }
                        , $REG_METERING_OUTPUT_ENERGY => { name => 'Metering Output Energy', fn => \&parseSingleFloat    }
                        , $REG_OUTPUT_MODE => { name => 'Output Mode', fn => \&parseUint8_t        }
                        , $REG_OUTPUT_ENABLE => { name => 'Output Enable',    fn => \&parseUint8_t        }
                        );

sub new {
  my ($class, $config) = @_;

  my $self = $class->SUPER::new($config);
  
  return $self;
}

sub deviceName {
  return 'FNIRSI DPS-150';
}

sub _sendRequest {
  my ($self, $command, $register, $data, $timeout_seconds) = @_;
  $timeout_seconds //= 1.0; # Default 1 second timeout
  
  my $serial = $self->{serial};
  
  # Prepare request
  my @bytes = ($register, length($data), unpack('C*', $data));
  my $checksum = sum(@bytes) & 0xff;
  my $request = pack('C*', $HEADER_REQUEST, $command, @bytes, $checksum);
  
  # Send request
  print "Sending ";
  hexprint($request);
  $serial->write($request);
  
  # Wait for response with timeout
  if ($timeout_seconds) {
    return $self->_receiveResponse($timeout_seconds);
  }
  return;
}

sub hexprint {
  my ($data) = @_;
  my @bytes = unpack('C*', $data);
  foreach my $byte (@bytes) {
    printf "%02x ", $byte;
  }
  print "\n";
}

sub _receiveResponse {
  my ($self, $timeout) = @_;

  $timeout //= 0.4;

  my $serial = $self->{serial};
  my $end_time = time + $timeout;
  my $hbyte;

  # Read until we get a response header byte
  while (time < $end_time) {
    $hbyte = $serial->read(1);
    #printf('%d byte: (%d) ', __LINE__, length($hbyte)); hexprint($hbyte);
    last if (ord($hbyte) eq $HEADER_RESPONSE);
    #printf "byte: %02x\n", ord($hbyte);
    sleep(0.001); # 1ms
  }

  return if ord($hbyte) ne $HEADER_RESPONSE;
  #my $now = time;
  #print "header byte found at ", $now, "\n";

  # Read the rest of the header
  my $header = '';
  while (time < $end_time) {
    my ($count, $bytes) = $serial->read(3);
    #printf('%d byte: [%d] (%d) ', __LINE__, $count, length($bytes)); hexprint($bytes);
    $header .= $bytes;
    last if length($header) == 3;
    sleep(0.001); # 1ms
  }
  my ($command, $register, $data_length) = unpack('C*', $header);

  my $read_length = $data_length + 1;
  my $data = '';
  while (time < $end_time) {
    my ($count, $bytes) = $serial->read($read_length);
    #printf('%d byte: [%d] (%d) ', __LINE__, $count, length($bytes)); hexprint($bytes);
    $data .= $bytes;
    last if length($data) == $read_length;
    sleep(0.001); # 1ms
  }

  return $self->_parseResponse($command, $register, $data_length, $data);
}

sub _parseResponse {
  my ($self, $command, $register, $data_length, $data) = @_;
  my @data = unpack('C*', $data);
  my $checksum = pop @data;
  my $check = sum($register, $data_length, @data) & 0xff;
  if ($checksum != $check) {
    return;
  }

  my $response = Milton::Interface::FNIRSI_DPS150::Response->new($command, $register, $data_length, $data);

  return $response;
}

sub expectResponse {
  my ($self, $command, $register, $response) = @_;

  if (!$response) {
    $response = $self->_receiveResponse;
  }

  while ($response && ($response->command ne $command || $response->register ne $register)) {
    $response = $self->_receiveResponse;
  }

  return $response;
}

sub _poll {
  my ($self) = @_;

  $self->_sendRequest($CMD_READ_DEVICE_DATA, $REG_ALL_OUTPUT, '\0');

  my $response = $self->expectResponse($CMD_READ_DEVICE_DATA, $REG_ALL_OUTPUT);

  if ($response) {
    my ($vout, $iout, $pout) = $response->floats;
    return ($vout, $iout);
  }

  return;
}

sub _initialize {
  my ($self) = @_;

  my ($vset, $iset, $vout, $iout, $pout, $on);

  $self->_sendRequest($CMD_DEVICE_CONNECT, 0, pack('C', 1));

#  if ($response) {
#    print "Response: ", $response->stringify, "\n";
#  }
#  while ($response = $self->_receiveResponse) {
#    print "connect: ", $response->stringify, "\n";
#  }

  if (!(($vout, $iout) = $self->_poll)) {
    die "Unable to read output data from DPS-150";
  }

  $self->_sendRequest($CMD_READ_DEVICE_DATA, $REG_V_SETP, '\0');
  my $response = $self->expectResponse($CMD_READ_DEVICE_DATA, $REG_V_SETP);
  $self->info('Connected to DPS-150') if $response;
  if ($response) {
    $vset = $response->float;
  } else {
    die "Unable to read voltage setpoint from DPS-150";
  }
  $self->_sendRequest($CMD_READ_DEVICE_DATA, $REG_I_SETP, '\0');
  $response = $self->expectResponse($CMD_READ_DEVICE_DATA, $REG_I_SETP);
  if ($response) {
    $iset = $response->float;
  } else {
    die "Unable to read current setpoint from DPS-150";
  }
  $self->_sendRequest($CMD_READ_DEVICE_DATA, $REG_OUTPUT_ENABLE, '\0');
  $response = $self->expectResponse($CMD_READ_DEVICE_DATA, $REG_OUTPUT_ENABLE);
  if ($response) {
    $on = $response->uint8_t;
  } else {
    die "Unable to read output state from DPS-150";
  }

  return ($vset, $iset, $on, $vout, $iout);
}

sub _on {
  my ($self, $flag) = @_;

  $self->_sendRequest($CMD_SET_DEVICE_DATA, $REG_OUTPUT_ENABLE, pack('C', $flag ? 1 : 0));

  return 1;
}

sub _setVoltage {
  my ($self, $voltage) = @_;

  $self->_sendRequest($CMD_SET_DEVICE_DATA, $REG_V_SETP, pack('f<', $voltage));

  return 1;
}

sub _setCurrent {
  my ($self, $current) = @_;

  $self->_sendRequest($CMD_SET_DEVICE_DATA, $REG_I_SETP, pack('f<', $current));

  return 1;
}

sub _disconnect {
  my ($self) = @_;

  if ($self->{serial}) {
    $self->_sendRequest($CMD_DEVICE_CONNECT, 0, pack('C', 0));
  }

  return $self->SUPER::_disconnect;
}

sub shutdown {
  my ($self) = @_;

  $self->_disconnect;

  return;
}

sub DESTROY {
  my $self = shift;

  $self->shutdown;

  return $self->SUPER::DESTROY;
}

package Milton::Interface::FNIRSI_DPS150::Response;

use strict;
use warnings qw(all -uninitialized);

sub new {
  my ($class, $command, $register, $data_length, $data) = @_;
  my $xlate = $REG_MAP{$register};
  my $cmd_name = $CMD_MAP{$command} // sprintf('Unknown (0x%02x)', $command);

  my $self = bless { command => $command
                   , cmd_name => $cmd_name
                   , register => $register
                   , data => $data
                   }, $class;

  if ($xlate) {
    $self->{name} = $xlate->{name};
    $xlate->{fn}->($self, $data);
  } else {
    $self->{name} = sprintf('Unknown (0x%02x)', $register);
  }

  return $self;
}

sub name {
  my ($self) = @_;
  return $self->{name};
}

sub command {
  my ($self) = @_;
  return $self->{command};
}

sub command_name {
  my ($self) = @_;
  return $self->{cmd_name};
}

sub register {
  my ($self) = @_;
  return $self->{register};
}

sub data {
  my ($self) = @_;
  return $self->{data};
}

sub float {
  my ($self) = @_;
  return $self->{float};
}

sub floats {
  my ($self) = @_;
  return $self->{floats};
}

sub uint8_t {
  my ($self) = @_;
  return $self->{uint8_t};
}

sub stringify {
  my ($self) = @_;

  my $str = sprintf('DPS-150 Response: Command %s: Register %s: ', $self->command_name, $self->name);
  if (exists $self->{float}) {
    $str .= sprintf(' %.3f', $self->float);
  } elsif (exists $self->{floats}) {
    my $sep = ' [ ';
    foreach my $float (@{$self->floats}) {
      $str .= sprintf('%s%.3f', $sep, $float);
      $sep = ', ';
    }
    $str .= ' ]';
  } elsif (exists $self->{uint8_t}) {
    $str .= sprintf(' %d', $self->uint8_t);
  } else {
    my $sep = ' [ ';
    foreach my $byte (unpack('C*', $self->data)) {
      $str .= sprintf('%s0x%02x', $sep, $byte);
      $sep = ', ';
    }
    $str .= ' ]';
  }

  return $str;
}

1;