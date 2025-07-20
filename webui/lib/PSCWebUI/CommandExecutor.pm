package PSCWebUI::CommandExecutor;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use IO::Select;
use IO::Pipe;
use POSIX qw(:sys_wait_h);

sub new {
  my ($class) = @_;
  
  my $self = {
    current_command => undef,
    command_pid => undef,
    command_output => undef,
    status => 'idle',
    column_names => undef,
    latest_data => {}
  };
  
  return bless $self, $class;
}

sub discover_devices {
  my ($self) = @_;
  
  my @devices = ();
  my $device_dir = 'device';
  
  if (-d $device_dir) {
    opendir(my $dh, $device_dir) or return @devices;
    
    while (my $file = readdir($dh)) {
      if ($file =~ /\.yaml$/) {
        my $device_name = $file;
        $device_name =~ s/\.yaml$//;
        push @devices, {
          name => $device_name,
          filename => $file,
          description => "Device: $device_name"
        };
      }
    }
    
    closedir($dh);
  }
  
  return @devices;
}

sub execute_reflow {
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
  
  # Create pipes for communication
  pipe(my $output_reader, my $output_writer) or croak "Failed to create pipe: $!";
  
  # Fork process
  my $pid = fork();
  if ($pid == 0) {
    # Child process
    close $output_reader;
    
    # Redirect stdout and stderr to pipe
    open(STDOUT, '>&', $output_writer) or die "Failed to redirect stdout: $!";
    open(STDERR, '>&', $output_writer) or die "Failed to redirect stderr: $!";
    
    # Execute command
    exec(@cmd) or die "Failed to exec: $!";
  } elsif ($pid > 0) {
    # Parent process
    close $output_writer;
    
    # Update state
    $self->{current_command} = 'reflow';
    $self->{command_pid} = $pid;
    $self->{command_output} = $output_reader;
    $self->{status} = 'running';
    
    return $pid;
  } else {
    croak "Failed to fork: $!";
  }
}

sub stop_command {
  my ($self) = @_;
  
  my $pid = $self->{command_pid};
  return unless $pid;
  
  # Send TERM signal
  kill 'TERM', $pid;
  
  # Update state
  $self->{status} = 'stopping';
  
  return $pid;
}

sub get_status {
  my ($self) = @_;
  
  my $status = {
    status => $self->{status},
    current_command => $self->{current_command},
    command_pid => $self->{command_pid},
    uptime => time()
  };
  
  # Add latest data if available and command is running
  if ($self->{latest_data} && $self->{status} eq 'running') {
    # Use flat structure with original data names
    foreach my $key (keys %{$self->{latest_data}}) {
      $status->{$key} = $self->{latest_data}->{$key};
    }
    
    warn "CommandExecutor: Status data - " . join(', ', map { "$_: $status->{$_}" } keys %$status) . "\n";  # Debug output
  } else {
    $self->{latest_data} = {};
  }
  
  return $status;
}

sub read_output {
  my ($self) = @_;
  
  my $output_fh = $self->{command_output};
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
      warn "CommandExecutor: Raw line: '$line'\n";  # Debug output
      return $self->parse_output_line($line);
    } else {
      # Process finished
      warn "CommandExecutor: Process finished\n";  # Debug output
      $self->command_finished();
      return undef;
    }
  } else {
    # No data ready to read
    warn "CommandExecutor: No data ready to read\n";  # Debug output
  }
  
  return undef;
}

sub parse_output_line {
  my ($self, $line) = @_;
  
  # Check for HEAD: prefix (header row)
  if ($line =~ /^HEAD: (.+)$/) {
    my $header = $1;
    my @columns = split(',', $header);
    
    # Store column names for future data parsing
    $self->{column_names} = \@columns;
    
    return {
      type => 'header',
      data => {
        columns => \@columns,
        timestamp => time()
      }
    };
  }
  
  # Check for DATA: prefix (CSV data row)
  if ($line =~ /^DATA: (.+)$/) {
    my $csv_data = $1;
    my @values = split(',', $csv_data);
    
    # Use stored column names or default if not available
    if (!defined $self->{column_names}) {
      return {
        type => 'console',
        data => {
          level => 'error',
          message => 'No column names available',
          timestamp => time()
        }
      };
    }
    
    # Create data hash using column names
    my $data = {};
    for (my $i = 0; $i < @{$self->{column_names}} && $i < @values; $i++) {
      my $key = $self->{column_names}->[$i];
      my $value = $values[$i];
      # Convert to numeric if possible
      $data->{$key} = $value =~ /^\d+\.?\d*$/ ? $value + 0 : $value;
    }
    
    # Store latest data for status updates
    $self->{latest_data} = $data;
    warn "CommandExecutor: Stored data: " . join(', ', map { "$_: $data->{$_}" } keys %$data) . "\n";  # Debug output
    
    return {
      type => 'data',
      data => $data
    };
  }
  
  # Check for INFO: prefix
  if ($line =~ /^INFO: (.+)$/) {
    return {
      type => 'console',
      data => {
        level => 'info',
        message => $1,
        timestamp => time()
      }
    };
  }
  
  # Check for WARN: prefix
  if ($line =~ /^WARN: (.+)$/) {
    return {
      type => 'console',
      data => {
        level => 'warning',
        message => $1,
        timestamp => time()
      }
    };
  }
  
  # Check for DEBUG: prefix
  if ($line =~ /^DEBUG: (.+)$/) {
    return {
      type => 'console',
      data => {
        level => 'debug',
        message => $1,
        timestamp => time()
      }
    };
  }
  
  # Non-prefixed lines are treated as errors
  return {
    type => 'console',
    data => {
      level => 'error',
      message => $line,
      timestamp => time()
    }
  };
}

sub command_finished {
  my ($self) = @_;
  
  # Wait for process to finish
  if ($self->{command_pid}) {
    waitpid($self->{command_pid}, 0);
  }
  
  # Reset state
  $self->{current_command} = undef;
  $self->{command_pid} = undef;
  $self->{command_output} = undef;
  $self->{status} = 'idle';
  $self->{column_names} = undef;
  $self->{latest_data} = {};
}

sub execute

sub execute_replay {
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
  
  # Create pipes for communication
  my $pipe = IO::Pipe->new() || croak "Failed to create pipe: $!";
  warn "CommandExecutor: Created pipe for replay command output\n";  # Debug output
  
  # Fork process
  my $pid = fork();
  if ($pid == 0) {
    # Child process
    close $output_reader;
    
    # Redirect stdout and stderr to pipe
    open(STDOUT, '>&', $output_writer) or die "Failed to redirect stdout: $!";
    open(STDERR, '>&', $output_writer) or die "Failed to redirect stderr: $!";
    
    # Execute command
    exec(@cmd) or die "Failed to exec: $!";
  } elsif ($pid > 0) {
    # Parent process
    close $output_writer;
    warn "CommandExecutor: Replay command started with PID $pid\n";  # Debug output
    
    # Update state
    $self->{current_command} = 'replay';
    $self->{command_pid} = $pid;
    $self->{command_output} = $output_reader;
    $self->{status} = 'running';
    
    return $pid;
  } else {
    croak "Failed to fork: $!";
  }
}

sub get_log_files {
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
      push @valid_files, {
        name => $file,
        size => $stat[7],
        mtime => $stat[9],
        readable_size => $self->format_file_size($stat[7])
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

sub format_file_size {
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