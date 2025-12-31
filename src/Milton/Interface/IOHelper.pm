package Milton::Interface::IOHelper;

use strict;
use warnings qw(all -uninitialized);
use Device::SerialPort;
use Carp qw(croak);

use Exporter qw(import);
our @EXPORT_OK = qw(device_compare check_device_readable check_device_writable);

sub new {
  my ($class, $self) = @_;

  croak "$class: device must be specified." if ! defined($self->{device});

  bless $self, $class;

  return $self;
}

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

sub check_device_group_perms {
  my ($logger, $device, $mask) = @_;

  # Check permissions and maybe suggest corrective actions.
  my $permissions = (stat($device))[2] & 07777;
  my $gid = (stat($device))[5];

  if ($permissions & $mask) {
    my $group = getgrgid($gid);
    my $user = getlogin || getpwuid($<);
    $logger->info("You may need to add your user to the $group group. Try running sudo usermod -aG $group $user");
  }
}

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

sub validateDevice {
  my ($self, $device) = @_;

  return if !-e $device;
  return if ! check_device_readable($self, $device);
  return if ! check_device_writable($self, $device);

  return 1;
}

sub tryConnection {
  my ($self, $device) = @_;

  die ref($self) .": tryConnection method not implemented.\n";
}

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

        $id->warn($failureMessage);
      }
    }

    $self->disconnect;
  }

  die ref($self) .": Could not connect to any devices matching $self->{device}\n";
}

sub sendRequest {
  my ($self, $request) = @_;

  die ref($self) .": sendRequest method not implemented.\n";
  return;
}

sub disconnect {
  my ($self) = @_;

  delete $self->{'connected-device'};
  return $self;
}

sub DESTROY {
  my ($self) = @_;

  $self->disconnect;

  return $self->SUPER::DESTROY;
}

1;
