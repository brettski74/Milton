package Milton::Interface::Utils::SCPIScanner;

use strict;
use warnings qw(all -uninitialized);
use Readonly;
use IO::File;
use Path::Tiny qw(path);
use List::Util qw(max);
use POSIX qw(floor);
use Milton::ValueTools qw(timestamp);
use Milton::Interface::SCPI::Serial;
use Milton::Interface::SCPI::USBTMC;

use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant DEBUG_OPERATIONS => 10;
use constant DEBUG_PROBE_1 => 100;
use constant DEBUG_PROBE_2 => 50;

use base 'Exporter';
our @EXPORT_OK = qw(scan_scpi_devices);

use Milton::Interface::SerialPortHelper qw(serial_port_exists);
use Milton::Config::Utils qw(find_config_files_by_path);
use Milton::Config::Path qw(resolve_writable_config_path);
use Milton::Config qw(get_yaml_parser);

Readonly my @BAUD_RATE => ( 115200, 9600, 19200, 38400, 57600, 4800 );

sub new {
  my ($class, %attributes) = @_;

  my $self = \%attributes;

  if (!exists $self->{logger}) {
    $self->{logger} = Milton::DataLogger->new({ tee => 1, enable => 1 });
  }

  $self->{delay} //= 1;

  bless $self, $class;

  $self->{devices} = $self->loadSupportedDevices();

  return $self;
}

sub loadSupportedDevices {
  my ($self) = @_;

  # Load all the SCPI interface configuration files that have an id-pattern defined.
  my @files = find_config_files_by_path('interface/*'
                                      , sub {
                                        my $doc = shift;

                                        return $doc->{package} =~ /^Milton::Interface::SCPI::/
                                            && defined($doc->{'id-pattern'});
                                      });

  my $result = {};
  foreach my $file (@files) {
    my $if = $file->{document}->{package};
    $if =~ s/^Milton::Interface::SCPI:://;
    $if = lc($if);

    my $mf = $file->{value};
    $mf =~ s/^.*\/([^\/]+)\/[^\/]+$/$1/;
    $mf = lc($mf);

    $file->{manufacturer} = $mf;
    $file->{type} = $if;

    $file->{'id-pattern-re'} = qr/$file->{document}->{'id-pattern'}/;
    
    if (!exists $result->{$if}) {
      $result->{$if} = [];
    }
    
    if (!exists $result->{$mf}) {
      $result->{$mf} = [];
    }

    push @{$result->{$if}}, $file;
    push @{$result->{$mf}}, $file;
  }

  # Should already be sorted by display name, since find_config_files_by_path does that.

  return $result;
}

sub scanSCPIUSBTMCDevices {
  my ($self, $glob) = @_;
  $glob //= '/dev/usbtmc[0-9]*';

  my $first = !wantarray;
  my @found;

  my @ports = glob($glob);

  PORT: foreach my $port (@ports) {
    my $interface;

    eval {
      $interface = Milton::Interface::SCPI::USBTMC->new({ device => $port
                                                        , logger => $self->{logger}
                                                        });
    };
    next PORT if $@ || !$interface;

    my $id = $interface->{'id-string'};
    
    if ($id && $id =~ /\w{6}/) {
      $self->info('Connected to device %s on %s', $id, $port);

      DEVICE: foreach my $device (@{$self->{devices}->{usbtmc}}) {
        if ($id =~ $device->{'id-pattern-re'}) {
          $self->info('Device %s matches. Using interface configuration file %s', $device->{displayName}, $device->{value});

          # Shallow copy the device hash to avoid modifying the original.
          my $result = { %$device };
          $result->{device} = $port;
          return $result if $first;
          push @found, $result;
          next PORT;
        }
      }    
    }

    my $device = $self->characterizeDevice($interface, $port);
    if ($device) {
      return $device if $first;
      push @found, $device;
    }
    next PORT;
  }

  return @found;
}

sub scanSCPISerialDevices {
  my ($self, $glob) = @_;
  $glob //= '/dev/tty{S,USB,ACM}[0-9]*';
  
  # In scalar context, only return the first device found
  my $first = !wantarray;
  my @found;

  my @ports = glob($glob);

  PORT: foreach my $port (@ports) {
    next if !serial_port_exists($port);

    $self->info('Scanning port %s', $port);

    BAUD: foreach my $baud (@BAUD_RATE) {
      $self->info('Trying baud rate %s', $baud);

      # For now we're only going to try 8N1 serial connections until such time as we find a device that requires something else.
      my $interface;
      eval {
        $interface = Milton::Interface::SCPI::Serial->new({ device => $port
                                                          , baudrate => $baud
                                                          , logger => $self->{logger}
                                                          });
      };
      next PORT if $@;

      my $id = $interface->{'id-string'};
      
      # Assume that a valid id string will have a string of at least 6 alphanumeric characters
      if ($id && $id =~ /\w{6}/) {
        $self->info('Connected to device %s on %s at %d baud', $id, $port, $baud);

        DEVICE: foreach my $device (@{$self->{devices}->{serial}}) {
          if ($id =~ $device->{'id-pattern-re'}) {
            $self->info('Device %s matches. Using interface configuration file %s', $device->{displayName}, $device->{value});
            
            # Shallow copy the device hash to avoid modifying the original.
            my $result = { %$device };
            $result->{device} = $port;
            return $result if $first;
            push @found, $result;
            next PORT;
          }
        }

        my $device = $self->characterizeDevice($interface, $port);
        if ($device) {
          return $device if $first;
          push @found, $device;
        }
        next PORT;
      }
    
      # Insert a delay between baud rate changes to allow the power supply to settle and be ready for a new command.
      sleep $self->{delay};
    }
  }

  return @found;
}

sub characterizeDeviceVoltage {
  my ($self, $interface) = @_;

  $self->debug('Characterizing device voltage') if DEBUG_LEVEL >= DEBUG_OPERATIONS;

  # Ensure that the output is off
  $interface->on(0);

  # Set the current to a relatively low value to avoid power limit issues while trying voltage set points
  $interface->sendCommand($interface->setCurrentCommand(1));

  my $vmax = 0;
  for (my $v = 12; $v <= 60; $v++) {
    # Don't use setVoltage because it will try to turn the output on.
    my $response = $interface->sendCommand($interface->setVoltageCommand($v));
    last if !$self->isResponseValid($response);

    my ($vset) = $interface->sendCommand($interface->voltageSetpointCommand);

    $vmax = max($vmax, $vset);

    $self->debug('Set voltage(%.3f) -> %.3f, max so far = %.3f', $v, $vset, $vmax) if DEBUG_LEVEL >= DEBUG_PROBE_1;

    # If the set voltage command didn't apply the requested voltage, then it was probably out of range.
    last if abs($vset - $v) > 0.01;
  }

  return $vmax;
}

sub characterizeDeviceCurrent {
  my ($self, $interface) = @_;

  $self->debug('Characterizing device current') if DEBUG_LEVEL >= DEBUG_OPERATIONS;

  # Ensure that the output is off
  $interface->on(0);

  # Set the voltage to a relatively low value to avoid power limit issues while trying current set points
  $interface->sendCommand($interface->setVoltageCommand(3));

  my $imax = 0;
  for (my $i = 1; $i <= 20; $i += 1/2) {
    my $response = $interface->sendCommand($interface->setCurrentCommand($i));
    last if !$self->isResponseValid($response);

    my ($iset) = $interface->sendCommand($interface->currentSetpointCommand);

    $imax = max($imax, $iset);

    $self->debug('Set current(%.3f) -> %.3f, max so far = %.3f', $i, $iset, $imax) if DEBUG_LEVEL >= DEBUG_PROBE_1;

    # If the set current command didn't apply the requested current, then it was probably out of range.
    last if abs($iset - $i) > 0.01;
  }

  return $imax;
}

sub characterizeDevicePower {
  my ($self, $interface, $vmax, $imax) = @_;

  $self->debug('Characterizing device power with vmax = %s, imax = %s', $vmax, $imax) if DEBUG_LEVEL >= DEBUG_OPERATIONS;

  # Ensure that the output is off
  $interface->on(0);

  my $pmax = 0;

  # Start somewhere around 1A and work our way up to the maximum power limit.
  my $pstart = floor($vmax/5 + 1) * 5;
  for (my $p = $pstart; $p <= 300; $p += 5) {
    my $i = floor($p / $vmax * 1000.0) / 1000.0;

    if ($i > $imax) {
      $i = $imax;
    }

    my $response = $interface->sendCommand($interface->setVoltageCommand($vmax) .';'. $interface->setCurrentCommand($i));
    last if !$self->isResponseValid($response);

    my ($vset) = $interface->sendCommand($interface->voltageSetpointCommand);
    my ($iset) = $interface->sendCommand($interface->currentSetpointCommand);
    my $pset = $vset * $iset;

    $pmax = max($pmax, $pset);

    $self->debug('Set voltage(%.3f) -> %.3f, Set current(%.3f) -> %.3f, pmax so far = %.3f', $vmax, $vset, $i, $iset, $pmax)
            if DEBUG_LEVEL >= DEBUG_PROBE_2;

    # If the set power command didn't apply the requested power, then it was probably out of range.
    last if ($i == $imax) || (abs($iset - $i) > 0.01) || (abs($vset - $vmax) > 0.01);
  }

  return $pmax;
}

sub isResponseValid {
  my ($self, $response) = @_;

  return $response !~ /ERR/i;
}

sub characterizeDevice {
  my ($self, $interface, $port) = @_;

  my ($make, $model) = $interface->sendCommand('*IDN?');
  my $portglob = $port;
  $portglob =~ s/[0-9]+$/[0-9]*/;
  my $filename = lc($make) .'/'. lc($model) .'.yaml';
  $filename =~ s/[^\w\.]+/-/g;
  my $device = { displayName => "$make $model"
               , value => "interface/user/$filename"
               , device => $port
               , document => { package => 'Milton::Interface::SCPI::USBTMC'
                             , 'id-pattern' => "^$make $model"
                             , device => $portglob
                             }
               };
  my $document = $device->{document};

  # A conservative command length limit until we know more.
  $document->{'command-length'} = 26;

  my $vmax = $self->characterizeDeviceVoltage($interface);
  return if $vmax <= 0.1;

  my $imax = $self->characterizeDeviceCurrent($interface);
  return if $imax <= 0.1;

  my $pmax = $self->characterizeDevicePower($interface, $vmax, $imax);
  return if $pmax <= 0.1;

  $document->{voltage} = { maximum => $vmax + 0.0, minimum => 2 };
  $document->{current} = { maximum => $imax + 0.0, minimum => 0.5 };
  $document->{power} = { maximum => $pmax + 0.0, minimum => 1 };

  my $path = resolve_writable_config_path($device->{value});
  my $dir = path($path)->parent;
  $dir->mkpath if !$dir->is_dir;
  my $ypp = get_yaml_parser();
  $ypp->dump_file($path, $document);

  my $fh = IO::File->new($path, 'a');
  if ($fh) {
    my $now = timestamp();
    $fh->print(<<"EOS");

# Some power supplies lock the user interface when they receive remote control commands
# To release this lock usually requires sending a command to the power supply as the last
# command prior to disconnecting. If your power supply stops responding to the buttons,
# knobs or other controls on it, you may need to add one or more shutdown commands such
# as some of the examples below.
# shutdown-commands:
#   - "*UNLOCK"
#   - SYST:LOC
#
### Generated by Milton::Interface::Utils::SCPIScanner on $now
EOS
    $fh->close;
  }

  return $device;
}

sub info {
  my $self = shift;

  return $self->{logger}->info(@_);
}

sub warning {
  my $self = shift;

  return $self->{logger}->warning(@_);
}

sub error {
  my $self = shift;

  return $self->{logger}->error(@_);
}

sub debug {
  my $self = shift;

  return $self->{logger}->debug(@_);
}

1;