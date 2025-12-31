package Milton::Interface::IOHelper;

use strict;
use warnings qw(all -uninitialized);
use Device::SerialPort;
use Carp qw(croak);

use Exporter qw(import);
our @EXPORT_OK = qw(device_compare check_device_readable check_device_writable);

=head1 NAME

Milton::Interface::IOHelper - Base class for IOHelper objects

=head1 DESCRIPTION

The IOHelper interface defines reusable functionality for low-level IO with instruments such as
power supplies. IOHelper objects may be used by some interface classes to implement the low-level
communication with the instrument while leaving the interface class to deal with the application
level protocol needed to communicate with the instrument.

=head1 CONSTRUCTOR

=head2 new($self)

Create a new IOHelper object.

=over

=item $self

A reference to a hash of configuration parameters. This hash will typically be blessed to become the
actual IOHelper object in question.

The named values that are understood by this class depends on the specific subclass being created, although
the following named values should be understood by most, if not all subclasses:

=over

=item device

The path to the device file to use for communication with the instrument. This may be a glob pattern to
specify multiple device files to try in the event that the device file can change over time, or it can
explicitly name a single device file if the user is confident that the device file will always be the
same.

=item logger

A reference to an object implementing the DataLogger interface.

=back

=cut

sub new {
  my ($class, $self) = @_;

  croak "$class: device must be specified." if ! defined($self->{device});
  croak "$class: logger must be specified." if ! defined($self->{logger});

  bless $self, $class;

  return $self;
}

=head2 device_compare($a, $b)

Utility function to compare device names for sorting in a manner that sorts similarly named devices in
increasing order of the numeric suffix.

=over

=item $a

The first device name to compare.

=item $b

The second device name to compare.

=item Return Value

An integer that is less than, equal to or greater than zero to indicate whether $a is considered to be
less than, equal to or greater than $b, respectively.

=back

=cut

sub device_compare {
  my ($a, $b) = @_;
  my ($atext, $anum) = $a =~ /^(.*?)([0-9]*)$/;
  my ($btext, $bnum) = $b =~ /^(.*?)([0-9]*)$/;
  my $result;

  if ($atext eq $btext) {
    $result = $anum <=> $bnum;
  } else {
    $result = $atext cmp $btext;
  }

  return $result;
}

=head2 check_device_group_perms($logger, $device, $mask)

Utility function to check the permissions of a device and suggest corrective actions if the permissions are not correct.

=over

=item $logger

A reference to an object implementing the DataLogger interface methods for logging info and warning messages.

=item $device

The path to the device for which permissions are to be checked.

=item $mask

The permission bitmask to check. Only the group permission bits are used. All other bits are
masked out before applying to the actual file permissions. This value will then be bitwise ANDed
with the actual file permissions and if the result matches the mask, then the permissions are
considered to be correct and a message suggesting adding the current user to the corresponding
group is output.

=back

=cut

sub check_device_group_perms {
  my ($logger, $device, $mask) = @_;

  # Mask out everything but the group permission bits.
  $mask = $mask & 0070;

  # If the mask is now blank, then there's nothing to do.
  return if !$mask;

  # Check permissions and maybe suggest corrective actions.
  my $permissions = (stat($device))[2] & 07777;
  my $gid = (stat($device))[5];

  if (($permissions & $mask) == $mask) {
    my $group = getgrgid($gid);
    my $user = getlogin || getpwuid($<);
    $logger->info("You may need to add your user to the $group group. Try running sudo usermod -aG $group $user");
  }
}

=head2 check_device_readable($logger, $device)

Utility function to check if a device is readable and suggest corrective actions if it is not.

=over

=item $logger

A reference to an object implementing the DataLogger interface methods for logging info and warning messages.

=item $device

The path to the device for which permissions are to be checked. If the device is not readable, the function
will attempt to sughest corrective actions, although this is currently only limited to seeing if group
membership might resolve the readability issue.

=item Return Value

Returns true if the device is readable, otherwise returns false.

=back

=cut

sub check_device_readable {
  my ($logger, $device) = @_;

  if (! -r $device) {
    my $ls = `ls -l $device`;
    chomp $ls;
    $logger->warning("Device $device is not readable: $ls");

    # Try to suggest corrective action.
    check_device_group_perms($device, 0040);

    return;
  }

  return 1;
}

=head2 check_device_writable($logger, $device)

Utility function to check if a device is writable and suggest corrective actions if it is not.

=over

=item $logger

A reference to an object implementing the DataLogger interface methods for logging info and warning messages.

=item $device

The path to the device for which permissions are to be checked. If the device is not writable, the function
will attempt to sughest corrective actions, although this is currently only limited to seeing if group
membership might resolve the writability issue.

=item Return Value

Returns true if the device is writable, otherwise returns false.

=back

=cut

sub check_device_writable {
  my ($logger, $device) = @_;

  if (! -r $device) {
    my $ls = `ls -l $device`;
    chomp $ls;
    $logger->warning("Device $device is not writable: $ls");

    # Try to suggest corrective action.
    check_device_group_perms($logger, $device, 0020);

    return;
  }

  return 1;
}

=head2 validateDevice($device)

Utility method to validate a device by checking if it exists, is readable and is writable.

=over

=item $device

The path to the device for which permissions are to be checked. If the device is not readable or writable, the function
will attempt to sughest corrective actions, although this is currently only limited to seeing if group
membership might resolve the readability or writability issue.

=item Return Value

Returns true if the device is valid, otherwise returns false.

=back

=cut

sub validateDevice {
  my ($self, $device) = @_;

  return if !-e $device;
  return if ! $self->check_device_readable($device);
  return if ! $self->check_device_writable($device);

  return 1;
}

=head2 tryConnection($device)

Utility method to try to connect to a device. This method is implemented by the subclass and is used to
attempt to connect to a device. This method should do the basic actions necessary to connect to the device
such as opening file handles or a serial port or whatever else may be necessary. It does not need to do any
validation of the device identity or other setup. That should normally be left to the existing code in
IOHelper that calls this method.

=over

=item $device

The path to the device to try to connect to.

=item Return Value

Returns true if the connection is successful, otherwise returns false.

=back

=cut

sub tryConnection {
  my ($self, $device) = @_;

  die ref($self) .": tryConnection method not implemented.\n";
}

=head2 connect($id)

Connect to a device. This may include trying multiple devices identified by a glob pattern
and performing identity checks to ensure that the connected device is the correct one. This
allows the system to reliably connect to a device when the name of the correct device file
can change over time - such as may be the case for USB serial or USBTMC devices that are only
created when detected and the numeric suffix may change depending on the order in which devices
were detected.

Subclasses should not need to override this method. The connection logic should be implemented
in the tryConnection method and device identification is implemented in the $id object's identify
method.

=over

=item $id

A reference to an object implementing the identification interface, which includes the identify
method. This will typically be the Milton::Interface object that is using this IOHelper object
for low-level communication.

=item Return Value

If successful, returns a reference to this IOHelper object, to allow for chaining of method.
If unsuccessful, throws an exception.

=back

=cut

sub connect {
  my ($self, $id) = @_;

  my @devices = glob($self->{device});
  if (scalar(@devices) == 0) {
    croak ref($self) .': could not find any devices matching ' . $self->{device};
  }

  @devices = sort { device_compare($a, $b) } @devices;

  my $failureMessage = undef;
  foreach my $device (@devices) {
    next if !$self->validateDevice($device);

    if ($self->tryConnection($device)) {
      $self->{'connected-device'} = $device;

      if ($id) {
         $failureMessage = $id->identify($self);
        return $self if !defined($failureMessage);

        $self->warning("Device $device: $failureMessage");
      }
    }

    # Clean up the failed connection attempt.
    $self->disconnect;
  }

  die ref($self) .": Could not connect or correctly identify any devices matching $self->{device}\n";
}

=head2 sendRequest($request)

Send a request to the device and return the response.

This must be implemented by subclasses to implement the actual communication with the device. This
typically involves writing the request to a filehandle or similar object and reading the response
back from a filehandle or similar object.

Note that the default implementation simply throws an exception, hence subclasses must implement this
method.

=over

=item $request

The request to send to the device. This should typically be sent exactly as provided. It is assumed
that the interface object has already formatted the request, including any request terminator for
dispatch.

=item Return Value

The response from the device. This should typically be returned exactly as received from the device.
it is assumed that the interface object will know how to parse the response as-is.

=back

=cut

sub sendRequest {
  my ($self, $request) = @_;

  die ref($self) .": sendRequest method not implemented.\n";
  return;
}

=head2 disconnect()

Disconnect from the device. This should close any open file handles or serial ports or whatever else
may be necessary to disconnect from the device.

Subclasses must implement this method to close any open file handles or other resources that were opened
by this object. They should also ensure to call SUPER::disconnect prior to returning. Typically this
should be done as the last thing in the subclass implementation. Subclass implementations should also
support the cleaning up of resources for failed connection attempts, as this method will be called
automatically after any failed connection attempt. Therefore the method shoudl check for the presence
of filehandles or other objects before attempting to close them and should remove references to those
closed objects once they are closed.

=over

=item Return Value

Returns a reference to this IOHelper object, to allow for chaining of methods.

=back

=cut

sub disconnect {
  my ($self) = @_;

  delete $self->{'connected-device'};
  return $self;
}

sub info {
  my ($self, $message) = @_;
  $self->{logger}->info($message);
}

sub warning {
  my ($self, $message) = @_;
  $self->{logger}->warning($message);
}

sub error {
  my ($self, $message) = @_;
  $self->{logger}->error($message);
}

sub debug {
  my ($self, $level, $message) = @_;
  $self->{logger}->debug($level, $message);
}

=head2 DESTROY

The destructor for the IOHelper object. The default implementation simply calls disconnect and is
probably sufficient for most subclasses. 

=over

=back

=cut

sub DESTROY {
  my ($self) = @_;

  $self->disconnect;
}

1;
