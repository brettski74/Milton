package MiltonUI::CommandExecutor;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use IO::Select;
use IO::Pipe;
use POSIX qw(:sys_wait_h);

use Mojo::IOLoop::ReadWriteFork;

use Milton::Config::Utils qw(get_device_names find_device_file);

sub new {
  my ($class, $logger) = @_;
  
  my $self = { currentCommand => undef
             , commandPID => undef
             , status => 'idle'
             , columnNames => undef
             , latestData => {}
             , logger => $logger
             };
  
  return bless $self, $class;
}

sub info {
  my $self = shift;

  if ($self->{logger}) {
    $self->{logger}->info(@_);
  } else {
    my $message = shift;
    
    if (@_) {
      printf "CommandExecutor: $message\n", @_;
    } else {
      print $message, "\n";
    }
  }

  return 1;
}

sub discoverDevices {
  return Milton::Config::Utils::get_device_names();
}

sub initializeCommand {
  my ($self, $params) = @_;

  print "params:\n";
  foreach my $key (sort keys %$params) {
    print "    $key: $params->{$key}\n";
  }

  my @cmd = qw(psc
               --logger Milton::WebDataLogger
               --log set-power:.1f
               --log predict-temperature:.1f
               --log device-temperature:.1f
               --log now-temperature:.1f
               --log back-prediction:.1f
               --log forward-prediction:.1f
               --log last-update-delay:.3f
               --log stage:s
               );

  if (defined $params->{ambient}) {
    push @cmd, '--ambient', $params->{ambient};
  }

  if (defined $params->{profile}) {
    push @cmd, '--profile', $params->{profile};
  }

  # --r0 already handles --reset, so don't specify both
  if (defined $params->{r0}) {
    push @cmd, '--r0', $params->{r0};
  } elsif ($params->{reset}) {
    push @cmd, '--reset';
  }

  if (defined $params->{cutoff}) {
    push @cmd, '--cutoff', $params->{cutoff};
  }

  if (defined $params->{limit}) {
    push @cmd, '--limit', $params->{limit};
  }

  if (defined $params->{device}) {
    my $device = $params->{device};
    if (! -f $device) {
      $device = find_device_file($device);
    }
    push @cmd, '--device', $device
             , '--log', 'device-temperature:.1f';
  }

  return @cmd;
}

sub executeOnePointCal {
  my ($self, $params) = @_;
  
  $params->{reset} = 1;

  my @cmd = $self->initializeCommand($params);
  
  push @cmd, 'power', 2, '--duration', 10, '--onepointcal';
  
  return $self->executeCommand('onePointCal', @cmd);
}

sub executeTune {
  my ($self, $params) = @_;

  my @cmd = $self->initializeCommand($params);

  push @cmd, 'tune';

  if (defined $params->{'predictor-calibration'}) {
    push @cmd, '--tune', $params->{'predictor-calibration'};
  }

  if (defined $params->{'controller-calibration'}) {
    push @cmd, '--ctrltune', $params->{'controller-calibration'};
  }

  return $self->executeCommand('tune', @cmd);
}

sub executeReflow {
  my ($self, $params) = @_;
  
  my @cmd = $self->initializeCommand($params);
  
  push @cmd, 'reflow';

  if (defined $params->{tune}) {
    push @cmd, '--tune', $params->{tune};
  }
  
  return $self->executeCommand('reflow', @cmd);
}

sub executeLinear {
  my ($self, $params) = @_;

  my @cmd = $self->initializeCommand($params);

  push @cmd, 'linear';
  push @cmd, $params->{profile};
  push @cmd, '--tune' if $params->{tune};

  return $self->executeCommand('linear', @cmd);
}

sub executeSetup {
  my ($self, $params) = @_;
  
  my @cmd = $self->initializeCommand($params);
  
  push @cmd, '--reset', 'reflow';

  if (defined $params->{'predictor-calibration'}) {
    push @cmd, '--tune', $params->{'predictor-calibration'};
  }

  if (defined $params->{'rtd-calibration'}) {
    push @cmd, '--rtdtune', $params->{'rtd-calibration'};
  }
  
  return $self->executeCommand('reflow', @cmd);
}

sub executeReplay {
  my ($self, $params) = @_;
  
  my $log_dir = 'log';
  my $file_path = "$log_dir/$params->{file}";
  unless (-f $file_path) {
    croak "Log file not found: $params->{file}";
  }
  
  my @cmd = $self->initializeCommand($params);
  
  push @cmd, 'replay';
  push @cmd, '--speed', $params->{speed} if defined $params->{speed};
  push @cmd, $file_path;
  
  return $self->executeCommand('replay', @cmd);
}

sub executePower {
  my ($self, $params) = @_;

  # Build command line
  my @cmd = $self->initializeCommand($params);
  
  # Add replay command and file
  push @cmd, 'power';
  push @cmd, '--duration', $params->{duration} if defined $params->{duration};
  push @cmd, $params->{power};

  return $self->executeCommand('power', @cmd);
}

sub executeRework {
  my ($self, $params) = @_;
  
  # Build command line
  my @cmd = $self->initializeCommand($params);

  push @cmd, 'rework';
  push @cmd, '--duration', $params->{duration} if defined $params->{duration};
  push @cmd, '--ramp', $params->{ramp} if defined $params->{ramp};
  push @cmd, '--monitor', $params->{monitor} if defined $params->{monitor};
  push @cmd, '--unsafe' if $params->{unsafe};
  push @cmd, $params->{temperature};

  return $self->executeCommand('rework', @cmd);
}

sub executeRth {
  my ($self, $params) = @_;

  my @cmd = $self->initializeCommand($params);

  push @cmd, 'rth';
  push @cmd, '--length', $params->{length}
           , '--width', $params->{width};

  if ($params->{mass} > 0) {
    push @cmd, '--mass', $params->{mass};
  }

  return $self->executeCommand('rth', @cmd);
}

sub executeRthcal {
  my ($self, $params) = @_;

  my @cmd = $self->initializeCommand($params);

  push @cmd, 'rth';
  push @cmd, '--calibration'
           , '--length', $params->{length}
           , '--width', $params->{width};

  foreach my $key (qw(test-delta-T preheat-time soak-time measure-time sample-time)) {
    if (defined $params->{$key}) {
      push @cmd, '--'. $key, $params->{$key};
    }
  }

  return $self->executeCommand('rth', @cmd);
}

sub stopCommand {
  my ($self) = @_;
  
  my $pid = $self->{commandPID};
  return unless $pid;
  
  # Update state
  $self->{status} = 'stopping';
  
  # Send TERM signal
  kill 'TERM', $pid;
  
  return $pid;
}

sub toJSName {
  my ($self, $name) = @_;
  $name =~ s/[-_]+(\w)/uc($1)/eg;
  return $name;
}

sub getStatus {
  my ($self) = @_;
  
  return { status => $self->{status}
         , currentCommand => $self->{currentCommand}
         , time => time()
         , data => $self->{latestData}
         };
}

sub addWebSocket {
  my ($self, $ws) = @_;

  push @{$self->{websockets}}, $ws;

  # Send them current status
  $self->_wsSendMessageTo($ws, $self->_formatDataMessage(undef, addWebSocket => 1));

  $self->_wsSendMessageTo($ws, $self->_formatConsoleMessage(info => 'Data connection confirmed by server'));

  return 1;
}

sub removeWebSocket {
  my ($self, $ws) = @_;

  @{$self->{websockets}} = grep { $_ ne $ws } @{$self->{websockets}};

  return 1;
}

sub parseOutputLine {
  my ($self, $line) = @_;
  
  while ($line =~ s/\a//) {
    $self->_wsSendMessage('beep', undef);
  }

  return if $line =~ /^\s*$/;

  my ($type, $data) = $line =~ /^(\w+): (.*)$/;

  if (!defined $type) {
    return $self->_consoleMessage('error', $line);
  }

  $type = lc($type);
  my $method = '_'. $type;
  if ($self->can($method)) {
    return $self->$method($data);
  } 

  return $self->_consoleMessage($type, $data);
}

sub _formatWSMessage {
  my ($self, $type, $data, %extra) = @_;

  return { type => $type
         , data => $data
         , time => time()
         , %extra
         };
}

sub _wsSendMessageTo {
  my ($self, $ws, $type, $data, %extra) = @_;

  $ws->send(Mojo::JSON::encode_json($self->_formatWSMessage($type, $data, %extra)));

  return 1;
}

sub _wsSendMessage {
  my ($self, $type, $data, %extra) = @_;

  my $msg = Mojo::JSON::encode_json($self->_formatWSMessage($type, $data, %extra));

  foreach my $ws (@{$self->{websockets}}) {
    $ws->send($msg);
  }

  return 1;
}

sub _head {
  my ($self, $line) = @_;

  my @columns = split(',', $line);
  
  foreach my $column (@columns) {
    $column = $self->toJSName($column);
  }

  $self->{columnNames} = \@columns;

  return 1;
}

sub _formatDataMessage {
  my ($self, $data, %extra) = @_;

  my $status;
  if (defined $data) {
    my @values = split(',', $data);

    $status = {};
    @{$status}{@{$self->{columnNames}}} = @values;

    $self->{latestData} = $status;
  } else {
    $status = $self->{latestData};
  }

  return (data => $status
        , currentCommand => $self->{currentCommand}
        , status => $self->{status}
        , %extra
        );
}
sub _data {
  my ($self, $data, %extra) = @_;

  $self->_wsSendMessage($self->_formatDataMessage($data, %extra));

  return 1;
}

sub _formatConsoleMessage {
  my ($self, $severity, $message, %extra) = @_;
  return ( console => { severity => $severity
                      , text => $message
                      }
         , %extra
         );
}

sub _consoleMessage {
  my ($self, $severity, $message, %extra) = @_;

  return $self->_wsSendMessage($self->_formatConsoleMessage($severity, $message, %extra));
}

sub commandFinished {
  my ($self) = @_;
  
  # Wait for process to finish
  if ($self->{commandPID}) {
    waitpid($self->{commandPID}, 0);
  }

  $self->_wsSendMessage('finish', $self->getStatus);
  
  # Reset state
  delete $self->{currentCommand};
  delete $self->{commandPID};
  delete $self->{rwf};
  $self->{status} = 'idle';
  delete $self->{columnNames};
  delete $self->{latestData};
}

sub getConfigPath {
  my ($self, @keys) = @_;

  return Milton::Config::getConfigPath('psc.yaml', @keys);
}

sub executeCommand {
  my ($self, $command, @cmd) = @_;
  
  # Check if command is already running
  if ($self->{status} ne 'idle') {
    croak 'Server busy';
  }

  $self->{status} = 'starting';

  my $rwf = Mojo::IOLoop::ReadWriteFork->new();

  $rwf->on(read => sub {
    my ($rwf, $data) = @_;

    my @lines = split /\n/, $data;
    foreach my $line (@lines) {
      $self->parseOutputLine($line);
    }
  });

  $rwf->on(finish => sub {
    $self->commandFinished();
  });

  $rwf->on(error => sub {
    my ($rwf, $error) = @_;
    $self->_consoleMessage(error => "Error: $error");
    $self->commandFinished();
  });

  $rwf->on(spawn => sub {
    my ($rwf) = @_;
    $self->{commandPID} = $rwf->pid;
    $self->{currentCommand} = $command;
    $self->{columnNames} = [];
    $self->{status} = 'running';

    $self->_data(undef, onSpawn => 1);
  });

  $self->info('Executing command: '. join(' ', @cmd));
  $rwf->run(@cmd);

  $self->_wsSendMessage('start', undef, currentCommand => $command, status => 'starting');

  $self->{rwf} = $rwf;

  return 1;
}

sub receiveMessage {
  my ($self, $ws, $message) = @_;
  
  return;
}

sub getLogFiles {
  my ($self) = @_;
  
  my @log_files = ();
  my $log_dir = 'log';
  
  # Check if log directory exists
  unless (-d $log_dir) {
    return @log_files;
  }
  
  # Open directory
  opendir(my $dh, $log_dir) or return @log_files;
  
  # Get all .csv files
  my @files = grep { /\.csv$/ && -f "$log_dir/$_" } readdir($dh);
  closedir($dh);
  
  # Filter files by size (> 1024 bytes) and sort by modification time (newest first)
  my @valid_files = ();
  foreach my $file (@files) {
    my $file_path = "$log_dir/$file";
    my @stat = stat($file_path);
    if (@stat && $stat[7] > 1024) {  # Size > 1024 bytes
      push @valid_files, { name => $file
                         , size => $stat[7]
                         , mtime => $stat[9]
                         , readable_size => $self->formatFileSize($stat[7])
                         };
    }
  }
  
  # Sort by modification time (newest first) and take top 20
  @valid_files = sort { $b->{mtime} <=> $a->{mtime} } @valid_files;
  @valid_files = @valid_files[0..19] if @valid_files > 20;
  
  # Extract just the filenames for the API response
  @log_files = map { $_->{name} } @valid_files;
  
  return @log_files;
}

sub formatFileSize {
  my ($self, $bytes) = @_;
  
  if ($bytes < 1024) {
    return "$bytes B";
  } elsif ($bytes < 1024 * 1024) {
    return sprintf("%.1f KB", $bytes / 1024);
  } else {
    return sprintf("%.1f MB", $bytes / (1024 * 1024));
  }
}

1; 
