package Milton::Config::Template;

use strict;
use warnings;

use Carp qw(croak);
use Path::Tiny qw(path);
use Milton::Config::Path qw(resolve_file_path resolve_writable_config_path);
use Milton::ValueTools qw(timestamp);

sub new {
  my ($class, %config) = @_;

  my $template = $config{template};
  my $fullpath = resolve_file_path($template)->stringify;

  croak "Template file '$template' not found" if !$fullpath;

  $config{fullpath} = $fullpath;
  
  my $self = \%config;

  if (!exists $self->{params}) {
    $self->{params} = {};
  }

  bless $self, $class;

  return $self;
}

=head2 setParameterValue($parameter, $value {, $parameter, $value, ...})

Set the value of a given named parameter for this template.

Multiple parameters can be set in a single call by passing a list of alternating names and values.

=over

=item $parameter

The name of the parameter.

=item $value

The value for this parameter.

=item Return Value

The template object itself to allow for method chaining.

=back

=cut

sub setParameterValue {
  my ($self, @parameters) = @_;
  my $params = $self->{params};

  while (@parameters) {
    my $name = shift @parameters;
    my $value = shift @parameters;

    $params->{$name} = $value;
  }

  return $self;
}

=head2 getParameterValue($parameter)

Get the value of a given named parameter for this template.

=over

=item $parameter

The name of the parameter.

=item Return Value

The value of the parameter.

=back

=cut

sub getParameterValue {
  my ($self, $parameter) = @_;
  return $self->{params}->{$parameter};
}

=head2 render([$output_file])

Render the template to a string.

If the output file is not specified, the template will be rendered to a default file path based on the template name.
This default name will be generated in one of two ways:

=over

If the template names ends with a .template extension, the default name will be the same as the template name with the
.template extension removed.

If the template name does not end with a .template extension, the default name will be the same as the template name
with .output appended to the end.

=back

If the output file already exists, the existing file will be renamed by appending a timestamp to the filename prior to
rendering the output file.

=over

=item $output_file

The file to which the output should be written.

If this is a reference, it is assumed to be an object implementing the IO::Handle interface. It will not be closed on
completion.

If this is not a reference, it is assumed to be a string representing the path to a file to be written. This may be a
relative path, in which case it will be resolved using the resolve_writable_config_path function. If it is an absolure
path, then it will be used as is.

=item Return Value

The full path to the output file if successful, otherwise undef.

=back

=cut

sub render {
  my ($self, $output_file) = @_;
  $output_file //= $self->defaultOutputFileName;
  my $out;
  my $output_path;
  my $output_string;

  # Clear any pre-existing error string
  delete $self->{'error-string'};

  my $in = IO::File->new($self->{fullpath}, 'r');
  return $self->_setErrorString('Failed to open %s: %s', $self->{fullpath}, $!) if !$in;

  if (ref $output_file) {
    $out = $output_file;
  } else {
    $output_path = resolve_writable_config_path($output_file);

    if ($output_path->is_file) {
      my $timestamp = timestamp();
      $output_path->move("$output_path.$timestamp");
    } else {
      my $dir = $output_path->parent;
      $dir->mkpath if !$dir->is_dir;
    }

    $output_string = $output_path->stringify;
    $out = IO::File->new($output_string, 'w');
    return $self->_setErrorString('Failed to open %s: %s', $output_string, $!) if !$out;
  }

  my $start_delim = $self->{'start-delimiter'} // $self->{delimiter} // '\\{\\{';
  my $end_delim = $self->{'end-delimiter'} // $self->{delimiter} // '\\}\\}';
  my $pattern = qr/$start_delim([-\w]+)$end_delim/;

  my $params = $self->{params};
  while (my $line = $in->getline) {
    $line =~ s/$pattern/$params->{$1}/g;

    $out->print($line);
  }

  $out->close if $output_path;
  $in->close;

  return $output_string;
}

sub _setErrorString {
  my ($self, $message, @params) = @_;

  if (@params) {
    $self->{'error-string'} = sprintf($message, @params);
  } else {
    $self->{'error-string'} = $message;
  }

  return;
}

=head2 errorString

Get the details of the last error that occurred.

=cut

sub errorString {
  my ($self) = @_;

  return $self->{'error-string'};
}

=head2 defaultOutputFileName

Get the default output file name for this template.

=over

=item Return Value

A string representing the default output file name for this template.

=back

=cut

sub defaultOutputFileName {
  my $self = shift;
  my $output = $self->{template};

  if ($output =~ s/\.template$//) {
    return $output;
  }

  return "$output.output";
}

1;