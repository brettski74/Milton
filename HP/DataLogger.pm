package HP::DataLogger;

use strict;
use warnings;
use Carp;
use IO::File;

=head1 NAME

HP::DataLogger - A data logger for the hotplate controller.

=head1 SYNOPSIS

  my $logger = HP::DataLogger->new($config);

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
  my ($class, $config) = @_;

  if (!$config->{enabled} || lc($config->{enabled}) eq 'false') {
    bless $config, 'HP::DataLogger::Null';
  } else {
    bless $config, $class;
    $config->{filename} = $config->_expandFilename($config->{fielname});
    $config->{fh} = IO::File->new($config->{filename}, 'w') || croak "Failed to open log file $config->{filename}: $!";
    $config->{formatString} = $config->_buildFormatString;
    $config->{header} = $config->_buildHeader;
    $config->{'column-names'} = [map { $_->{key} } @{$config->{columns}}];

    $config->{fh}->print($config->{header});
  }

  return $config;
}

sub _expandFilename {
  my ($self, $filename) = @_;
  my ($year, $month, $day, $hour, $minute, $second) = localtime;
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

  $self->{fh}->printf($self->{formatString}, @{$status}{@{$self->{'column-names'}}});
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

=head2 close

Closes the log file.

=cut

sub close {
  my ($self) = @_;

  $self->{fh}->close;
}

package HP::DataLogger::Null;

sub log {
  return;
}

sub logFilename {
  return;
}

sub logColumns {
  return;
}

1;