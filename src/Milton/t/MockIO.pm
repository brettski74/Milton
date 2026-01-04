package Milton::t::MockIO;

use strict;
use warnings qw(all -uninitialized);

use Milton::ValueTools;

use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level();

use Exporter qw(import);
our @EXPORT_OK = qw(inject_prompt add_response clear_responses);

my @prompt_responses = ();

sub mock_prompt {
  my ($prompt, $default) = @_;

  print "prompt: $prompt\n" if DEBUG_LEVEL >= 50;

  if (@prompt_responses) {
    my $response = shift @prompt_responses;
    chomp $response;
    $response =~ s/^\s+//;
    $response =~ s/\s+$//;

    if (!defined($response) || $response eq '') {
      print "default response: $default\n" if DEBUG_LEVEL >= 100;
      return $default;
    }

    print "response: $response\n" if DEBUG_LEVEL >= 100;

    return $response;
  }

  my $response = Milton::ValueTools::prompt($prompt, $default);
  print "response: $response\n" if DEBUG_LEVEL >= 100;
  return $response;
}

sub inject_prompt {
  no warnings qw(redefine);
  my ($namespace) = @_;

  eval '*'. $namespace .'::prompt = \&mock_prompt';
}

sub add_response {
  push @prompt_responses, @_;
}

sub clear_responses {
  @prompt_responses = ();
}

1;