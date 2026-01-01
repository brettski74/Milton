package Milton::DataLogger;

use strict;
use warnings qw(all -uninitialized);
use Carp qw(croak);
use IO::File;
use Path::Tiny qw(path);
use Milton::Config::Path qw(resolve_file_path search_path standard_search_path);
use Readonly;
use mro;

use Exporter qw(import);
our @EXPORT_OK = qw(get_namespace_debug_level $DEBUG_LEVEL_FILENAME);

Readonly our $DEBUG_LEVEL_FILENAME => 'milton-debug.cfg';

=head1 NAME

Milton::DataLogger - A data logger for the hotplate controller.

=head1 SYNOPSIS

  my $logger = Milton::DataLogger->new($config);

  $logger->log($status);

  $logger->logFilename;
  $logger->logColumns;
  $logger->close;

=head1 DESCRIPTION

A simple data logger for the hotplate controller that allows a configurable set of output columns and output
formats to be specified. This provides a consistent interface for logging data for various commands for later
review, reporting and analysis.

=head1 CONSTRUCTOR

=over

=item $config

A hash reference containing the configuration for the data logger.

=back

=cut

sub new {
  my ($class, $config, @extra) = @_;
  $config //= {};

  my $self = { %$config, @extra };

  if (!$self->{enabled} || lc($self->{enabled}) eq 'false') {
    $self = { enabled => 0, 'column-names' => [] };
    bless $self, 'Milton::DataLogger::Null';
  } else {
    bless $self, $class;
    $self->{filename} = $self->_expandFilename($self->{filename});
    my $logpath = path($self->{filename})->parent;
    $logpath->mkpath if !$logpath->exists;
    $self->{fh} = IO::File->new($self->{filename}, 'w') || croak "Failed to open log file $self->{filename}: $!";
    $self->rebuild;
    $self->{buffer} = [];

    if ($self->{tee} && $self->{tee} ne 'false') {
      $self->{tee} = 1;
    }
  }

  return $self;
}

sub rebuild {
  my ($self) = @_;

  $self->{formatString} = $self->_buildFormatString;
  $self->{header} = $self->_buildHeader;
  $self->{'column-names'} = [map { $_->{key} } @{$self->{columns}}];
}

sub writeHeader {
  my ($self) = @_;

  return unless $self->{fh};

  $self->{fh}->print($self->{header});
  $self->consoleOutput('HEAD', $self->{header}) if $self->{tee};
}

sub includesColumn {
  my ($self, $column) = @_;

  return grep { $_->{key} eq $column } @{$self->{columns}};
}

sub addColumn {
  my ($self, %col) = @_;

  if (defined $col{key} && $col{key} ne '' && !$self->includesColumn($col{key})) {
    push @{$self->{columns}}, { %col };
    $self->rebuild;
  }
}

sub addColumns {
  my ($self, @cols) = @_;
  my $count = 0;

  foreach my $col (@cols) {
    if (defined $col->{key} && $col->{key} ne '' && !$self->includesColumn($col->{key})) {  
      push @{$self->{columns}}, $col;
      $count++;
    }
  }

  $self->rebuild if $count;
}

sub _expandFilename {
  my ($self, $filename) = @_;
  my ($second, $minute, $hour, $day, $month, $year) = localtime;
  my $timestamp = sprintf('%04d%02d%02d-%02d%02d%02d', $year+1900, $month+1, $day, $hour, $minute, $second);

  $filename =~ s/%c/$self->{command}/g;
  $filename =~ s/%d/$timestamp/g;

  return $filename;
}

sub _buildFormatString {
  my ($self) = @_;

  my $formatString = '';

  foreach my $column (@{$self->{columns}}) {
    $formatString .= '%' . ($column->{format} || 's') . ',';
  }

  $formatString =~ s/,$/\n/;

  return $formatString;
}

sub _buildHeader {
  my ($self) = @_;

  my $header = '';

  foreach my $column (@{$self->{columns}}) {
    $header .= $column->{key} . ',';
  }

  $header =~ s/,$/\n/;

  return $header;
}

=head1 METHODS

=head2 log($status)

=over

=item $status

A hash reference containing the status data to log.

=back

=cut

sub log {
  my ($self, $status) = @_;

  return unless $self->{fh};

  my @values = ();

  foreach my $column (@{$self->{columns}}) {
    my $tmp = $status;
    my $name = $column->{key};

    while ($name =~ s/^([^.]+)\.//) {
      $tmp = $tmp->{$1};
    }

    push(@values, $tmp->{$name});
  }

  my $logOutput = sprintf($self->{formatString}, @values);
  $self->{fh}->print($logOutput);

  if ($self->{tee}) {
    if ($self->{hold}) {
      push @{$self->{buffer}}, $logOutput;
    }
    else {
      $self->consoleOutput('DATA', $logOutput);
    }
  }
}

sub info {
  my ($self, $message, @args) = @_;

  if (@args) {
    $message = sprintf($message, @args);
  }

  $self->consoleOutput('INFO', $message);
}

sub warning {
  my ($self, $message, @args) = @_;

  if (@args) {
    $message = sprintf($message, @args);
  }

  $self->consoleOutput('WARN', $message);
}

sub error {
  my ($self, $message, @args) = @_;

  if (@args) {
    $message = sprintf($message, @args);
  }

  $self->consoleOutput('ERROR', $message);
}

sub debug {
  my ($self, $message, @args) = @_;

  if (@args) {
    $message = sprintf($message, @args);
  }
  
  $self->consoleOutput('DEBUG', $message);
}

sub debugLevel {
  my $self = shift;

  my $rc = $self->{'debug-level'};

  if (@_) {
    $self->{'debug-level'} = shift;
  }

  return $rc;
}

sub consoleProcess {
  my ($self, $type, $output) = @_;

  if ($output !~ /\n$/) {
    return "$output\n";
  }

  return $output;
}

sub consoleOutput {
  my ($self, $type, $output) = @_;

  print $self->consoleProcess($type, $output);
}

=head2 logFilename

Returns the log file name.

=cut

sub logFilename {
  my ($self) = @_;

  return $self->{filename};
}

=head2 logColumns

Returns the list of column names to be logged.

=cut

sub logColumns {
  my ($self) = @_;

  return @{$self->{'column-names'}};
}

=head2 hold

Holds logging until released. This can be used when obtaining input from the user to prevent the continual log output from creating confusion on screen.
The logged data will be buffered internally and output after release is called.

=cut

sub hold {
  my ($self) = @_;

  $self->{hold} = 1;
}

=head2 flush

Outputs any buffered data due to a hold but does not release the hold.

=cut

sub flush {
  my ($self) = @_;

  my $buffer = $self->{buffer};
  while (my $logOutput = shift @$buffer) {
    print $logOutput if $self->{tee};
  }
}

=head2 release

Releases the hold and outputs any buffered data.

=cut

sub release {
  my ($self) = @_;

  $self->flush;
  $self->{hold} = 0;
  $self->flush;
}

=head2 close

Closes the log file.

=cut

sub close {
  my ($self) = @_;

  if ($self->{fh}) {  
    my $rc = $self->{fh}->close;
    
    # Re-bless myself as a null logger
    bless $self, 'Milton::DataLogger::Null';

    return $rc;
  }

  return;
}

my %DEBUG_LEVELS;
my $DEBUG_LEVELS_LOADED = undef;

# Keep the debug level loadign logic as simple and free of dependencies as possible, since this needs
# to be callable at compile-time for efficiency.
sub load_debug_levels {
  return if $DEBUG_LEVELS_LOADED;
  #print "load_debug_levels: called\n";

  $DEBUG_LEVELS_LOADED = 1;

  %DEBUG_LEVELS = ();

  my @search_path = search_path();
  if (!@search_path) {
    standard_search_path();
  }

  my $path = resolve_file_path($DEBUG_LEVEL_FILENAME, 1);
  return if !$path;
  return if !$path->is_file;

  my $pathstring = $path->stringify;
  #print "path to debug level file: $pathstring\n";

  local $_;
  local $.;

  open(DBGLVL, '<', $pathstring) || return;

  while (<DBGLVL>) {
    # Strip off any leading or trailing whitespace
    chomp;
    s/^\s+//;
    s/\s+$//;
    #print "DEBUG LEVEL line: $_\n";

    next if /^#/;

    if (/^((\w+::)*\w+)\s*=\s*(\d+)$/) {
      $DEBUG_LEVELS{$1} = $3;
      #print "DEBUG LEVEL $1 = $3\n";
    } else {
      warn "$pathstring:$.: Syntax error: $_\n";
    }
  }

  CORE::close(DBGLVL);
  #print "DEBUG LEVELS: finished\n";
}

=head1 FUNCTIONS

=head2 get_namespace_debug_level($namespace)

Returns the debug level for the specified namespace.

=over

=item $namespace

An optional string identifying the namespace for which the debug level is desired. If not specified,
it will be defaulted to the namespace of the caller. Debug levels are loaded from the milton-debug.cfg
file, which will be loaded from the configuration search path. If an entry for the specified namespace
is not found, then the debug level will be defaulted to 0.

=item Return Value

The debug level for the specified namespace.

=back

=cut

sub get_namespace_debug_level {
  my ($namespace) = @_;

  if (!$namespace) {
    my ($package, $filename, $line) = caller(1);

    $namespace = $package;
  }
  #print "get_namespace_debug_level: namespace = $namespace\n";

  load_debug_levels() if !$DEBUG_LEVELS_LOADED;

  my $linear_isa = mro::get_linear_isa($namespace);
  #print "get_namespace_debug_level: linear_isa = ", join(', ', @$linear_isa) ."\n";

  foreach my $isa (@$linear_isa) {
    if (exists $DEBUG_LEVELS{$isa}) {
      #print "DEBUG_LEVEL $isa($namespace) = $DEBUG_LEVELS{$isa}\n";
      return $DEBUG_LEVELS{$isa} || 0;
    }
  }

  return 0;
}


package Milton::DataLogger::Null;

use base qw(Milton::DataLogger);

sub log {
  return;
}

sub close {
  return;
}

1;
