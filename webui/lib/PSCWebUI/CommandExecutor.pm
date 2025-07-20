package PSCWebUI::CommandExecutor;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use IO::Select;
use IO::Pipe;
use POSIX qw(:sys_wait_h);

sub new {
  my ($class) = @_;
  
  my $self = { 'current-command' => undef
             , 'command-pid' => undef
             , 'command-output' => undef
             , status => 'idle'
             , 'column-names' => undef
             , 'latest-data' => {}
             };

  
  
  return bless $self, $class;
}

sub discoverDevices {
  my ($self) = @_;
  
  my @devices = ();
  my $device_dir = 'device';
  
  if (-d $device_dir) {
    opendir(my $dh, $device_dir) or return @devices;
    
    while (my $file = readdir($dh)) {
      if ($file =~ /\.yaml$/) {
        my $device_name = $file;
        $device_name =~ s/\.yaml$//;
        push @devices, { name => $device_name
                       , filename => $file
                       , description => "Device: $device_name"
                       };
      }
    }
    
    closedir($dh);
  }
  
  return @devices;
}

sub executeReflow {
  my ($self, $device_name) = @_;
  
  # Check if command is already running
  if ($self->{status} eq 'running') {
    croak 'Command already running';
  }
  
  # Build command line
  my @cmd = ('perl', 'psc.pl');
  
  # Add logger option for WebDataLogger
  push @cmd, '--logger', 'PowerSupplyControl::WebDataLogger';
  push @cmd, '--log', 'predict-temperature:.1f';
  
  # Add device if specified
  if ($device_name) {
    push @cmd, '--device', $device_name;
  }
  
  # Add reflow command
  push @cmd, 'reflow';
  
  return $self->executeCommand('reflow', @cmd);
}

sub stopCommand {
  my ($self) = @_;
  
  my $pid = $self->{'command-pid'};
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
  
  my $status = { status => $self->{status}
               , 'currentCommand' => $self->{'current-command'}
               , 'commandPid' => $self->{'command-pid'}
               , uptime => time()
               };
  
  # Add latest data if available and command is running
  if ($self->{'latest-data'} && $self->{status} eq 'running') {
    # Use flat structure with original data names
    foreach my $key (keys %{$self->{'latest-data'}}) {
      $status->{$self->toJSName($key)} = $self->{'latest-data'}->{$key};
    }
    
#    warn "CommandExecutor: Status data - " . join(', ', map { "$_: $status->{$_}" } keys %$status) . "\n";  # Debug output
  } else {
    $self->{'latest-data'} = {};
  }
  
  return $status;
}

sub readOutput {
  my ($self) = @_;
  
  my $output_fh = $self->{'command-output'};
  unless ($output_fh) {
    warn "CommandExecutor: No output filehandle available\n";  # Debug output
    return undef;
  }
  
  my $select = IO::Select->new($output_fh);
  my @ready = $select->can_read(0); # Non-blocking read
  
  if (@ready) {
    my $line = <$output_fh>;
    if (defined $line) {
      chomp $line;
#      warn "CommandExecutor: Raw line: '$line'\n";  # Debug output
      return $self->parseOutputLine($line);
    } else {
      # Process finished
#      warn "CommandExecutor: Process finished\n";  # Debug output
      $self->commandFinished();
      return;
    }
#  } else {
    # No data ready to read
#    warn "CommandExecutor: No data ready to read\n";  # Debug output
  }
  
  return;
}

sub parseOutputLine {
  my ($self, $line) = @_;
  
  # Check for HEAD: prefix (header row)
  if ($line =~ /^HEAD: (.+)$/) {
    my $header = $1;
    my @columns = split(',', $header);
    
    # Store column names for future data parsing
    $self->{'column-names'} = \@columns;
    my @jscolumns = ();
    foreach my $column (@columns) {
      push @jscolumns, $self->toJSName($column);
    }
    
    return { type => 'header'
           , data => { columns => \@jscolumns
                     , timestamp => time()
                     }
           };
  }
  
  # Check for DATA: prefix (CSV data row)
  if ($line =~ /^DATA: (.+)$/) {
    my $csv_data = $1;
    my @values = split(',', $csv_data);
    
    # Use stored column names or default if not available
    if (!defined $self->{'column-names'}) {
      return { type => 'console'
             , data => { level => 'error'
                       , message => 'No column names available'
                       , timestamp => time()
                       }
             };
    }
    
    # Create data hash using column names
    my $data = {};
    for (my $i = 0; $i < @{$self->{'column-names'}} && $i < @values; $i++) {
      my $key = $self->{'column-names'}->[$i];
      my $value = $values[$i];
      # Convert to numeric if possible
      $data->{$self->toJSName($key)} = $value =~ /^\d+\.?\d*$/ ? $value + 0 : $value;
    }
    
    # Store latest data for status updates
    $self->{'latest-data'} = $data;
    warn "CommandExecutor: Stored data: " . join(', ', map { "$_: $data->{$_}" } keys %$data) . "\n";  # Debug output
    
    return { type => 'data'
           , data => $data
           };
  }
  
  # Check for INFO: prefix
  if ($line =~ /^INFO: (.+)$/) {
    return { type => 'console'
           , data => { level => 'info'
                     , message => $1
                     , timestamp => time()
                     }
           };
  }
  
  # Check for WARN: prefix
  if ($line =~ /^WARN: (.+)$/) {
    return { type => 'console'
           , data => { level => 'warning'
                     , message => $1
                     , timestamp => time()
                     }
           };
  }
  
  # Check for DEBUG: prefix
  if ($line =~ /^DEBUG: (.+)$/) {
    return { type => 'console'
           , data => { level => 'debug'
                     , message => $1
                     , timestamp => time()
                     }
           };
  }
  
  # Non-prefixed lines are treated as errors
  return { type => 'console'
           , data => { level => 'error'
                     , message => $line
                     , timestamp => time()
                     }
         };
}

sub commandFinished {
  my ($self) = @_;
  
  # Wait for process to finish
  if ($self->{'command-pid'}) {
    waitpid($self->{'command-pid'}, 0);
  }
  
  # Reset state
  $self->{'current-command'} = undef;
  $self->{'command-pid'} = undef;
  $self->{'command-output'} = undef;
  $self->{status} = 'idle';
  $self->{'column-names'} = undef;
  $self->{'latest-data'} = {};
}

sub executeCommand {
  my ($self, $command, @cmd) = @_;
  
  # Check if command is already running
  if ($self->{status} eq 'running') {
    croak 'Command already running';
  }

  my $pipe = IO::Pipe->new() || croak "Failed to create pipe: $!";
  my $pid = fork();
  if ($pid) {
    # Parent process
    $pipe->reader();
    $self->{'command-pid'} = $pid;
    $self->{'command-output'} = $pipe;
    $self->{status} = 'running';
    $self->{'current-command'} = $command;
    return $pid;
  } elsif ($pid == 0) {
    # Child process
    $pipe->writer();
    open(STDOUT, '>&', $pipe) || die "Failed to redirect stdout: $!";
    open(STDERR, '>&', $pipe) || die "Failed to redirect stderr: $!";

    exec(@cmd) || die "Failed to exec: $!";
  }

  croak "fork failed: $!"; 
}

sub executeReplay {
  my ($self, $file_name) = @_;
  
  # Check if command is already running
  if ($self->{status} eq 'running') {
    croak 'Command already running';
  }
  
  # Validate file exists and is in log directory
  my $log_dir = 'log';
  my $file_path = "$log_dir/$file_name";
  unless (-f $file_path) {
    croak "Log file not found: $file_name";
  }
  
  # Build command line
  my @cmd = ('perl', 'psc.pl');
  
  # Add logger option for WebDataLogger
  push @cmd, '--logger', 'PowerSupplyControl::WebDataLogger';
  
  # Add replay command and file
  push @cmd, 'replay', $file_path;
  
  return $self->executeCommand('replay', @cmd);
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