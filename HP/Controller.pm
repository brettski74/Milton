package HP::Controller;

=head1 NAME

HP::Controller - Base class to define the interface for HP control modules.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

Create a new controller object with the specified properties.

=cut

sub new {
  my ($class, $config, $interface) = @_;

  $config->{interface} = $interface;

  bless $config, $class;

  return $config;
}

=head2 getTemperature($status)

Get the current temperature of the hotplate.

=over

=item $status

The current status of the hotplate.

=cut

sub getTemperature {
  return;
}

=head2 setTemperature($currentTemperature, $futureTemperature, $now, $when)

Attempt to achieve a certain hotplate temperature by a specified time.

=over

=item $currentTemperature

The estimated current temperature of the hotplate.

=item $futureTemperature

The desired temperature to achieve on the hotplate.

=item $now

A timestamp representing the current number of seconds since a fixed epoch.

=item $when

A timestamp representing the number of seconds since the fixed epoch when we expect the $futureTemperature to be reached on the hotplate.

=back

=cut

sub setTemperature {
  return;
}

1;
