package HP::Controller;

=head1 NAME

HP::Controller - Base class to define the interface for HP control modules.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new($config)

Create a new controller object with the specified properties.

This class merely defines the interface for controllers. It does not implement any functionality.

The sole purpose of a controller is to provide a method to set the temperature of the hotplate. More direct control
based on power, voltage or current can be achieved directly via the HP::Interface object.

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

=head2 setTemperature($status, $target_temp

Attempt to achieve a certain hotplate temperature by the next sample period.

=over

=item $status

The hash representing the current status of the hotplate.

=item $target_temp

The desired temperature to achieve on the hotplate by the next sample period.

=item Return Value

The power to be applied to the hotplate to achieve the target temperature.

=back

=cut

sub setTemperature {
  return;
}

1;
