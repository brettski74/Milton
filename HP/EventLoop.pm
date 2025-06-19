package HP::EventLoop;

=head1 NAME

Reflow::Controller

=head1 DESCRIPTION

Implement the main event loop environment in which the overall hotplate controller commands can run.

=head2 new(<named arguments>)

Create a new event loop object.

=over

=item command

An instance of an object implementing the HP::Command interface. This object provides the command logic for the
current user command being run.

=item config

An HP::Config object defining the static configuration for hotplate control.

=back

=cut

sub new {
  my $class = shift;
  my $self = { @_ };

  bless $self, $class;

  return $self;
}





