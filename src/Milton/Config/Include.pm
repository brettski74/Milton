package Milton::Config::Include;

use strict;
use warnings;

use Carp qw(croak);

use base 'YAML::PP::Schema::Include';

sub include {
  my ($self, $constructor, $event) = @_;

  return $self->loader->($self, $self->yp, $event->{value});
}

1;