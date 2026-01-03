package Milton::Interface::Utils::t::SCPIMock;

use strict;
use warnings qw(all -uninitialized);
use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level();
use constant REQUEST_DEBUG => 50;
use constant RESPONSE_DEBUG => 100;

use base qw(Milton::Interface::SCPICommon);

sub new {
  my $class = shift;

  my $self = $class->SUPER::new({ logger => Milton::DataLogger->new({ enabled => 1, tee => 1 }) });

  $self->addMock(@_);

  return $self;
}

sub initializeConnection {
  my ($self) = @_;

  my $helper = Milton::Interface::Utils::t::SCPIMock::Mock::Helper->new({ logger => $self->{logger}, device => 'dummy' });

  return $helper;
}

sub addMock {
  my $self = shift;

  $self->{helper}->addMock(@_);

  return $self;
}

sub addSetpointMock {
  my $self = shift;

  $self->{helper}->addSetpointMock(@_);

  return $self;
}

sub suffix {
  my $self = shift;

  return $self->{helper}->suffix(@_);
}

sub setMaxCommandLength {
  my $self = shift;

  return $self->{helper}->setMaxCommandLength(@_);
}

package Milton::Interface::Utils::t::SCPIMock::Mock::Helper;

use strict;
use warnings qw(all -uninitialized);
use base qw(Milton::Interface::IOHelper);
use Milton::DataLogger qw(get_namespace_debug_level);

# Get the debug level for this namespace
use constant DEBUG_LEVEL => get_namespace_debug_level('Milton::Interface::Utils::t::SCPIMock::Mock');
use constant REQUEST_DEBUG => 50;
use constant RESPONSE_DEBUG => 100;

sub new {
  my ($class, $self) = @_;

  $self->{mock}->{'VOLT?'} //= '3.00';
  $self->{mock}->{'CURR?'} //= '1.000';

  $self = $class->SUPER::new($self);

  return $self;
}

sub tryConnection {
  return 1;
}

sub connect {
  my $self = shift;
  return $self;
}

sub disconnect {
  my $self = shift;

  $self->SUPER::disconnect;

  return $self;
}

sub addMock {
  my $self = shift;

  while (@_) {
    my $request = shift;
    my $response = shift;

    $self->{mock}->{$request} = $response;
  }

  return $self;
}

sub suffix {
  my $self = shift;

  my $result = $self->{'suffix'};

  if (@_) {
    my $value = shift;

    $self->{'suffix'} = $value;
  }

  return $result;
}

sub setMaxCommandLength {
  my ($self, $length) = @_;

  $self->{'max-command-length'} = $length;

  return $self;
}

sub sendRequest {
  my ($self, $request) = @_;
  chomp $request;
  $self->debug('Sending SCPI Command: %s', $request) if DEBUG_LEVEL >= REQUEST_DEBUG;

  if ($self->{'max-command-length'} <= 0 || length($request) <= $self->{'max-command-length'}) {
    if ($request =~ /;/) {
      my @requests = split(/;/, $request);
      my $error = undef;
      foreach my $req (@requests) {
        my $response = $self->sendRequest($req);
        $error = $response =~ /ERR/i;
        last if $error;
      }

      if (!$error) {
        my $response = $self->{suffix};
        $self->debug('Command response: %s', $response) if DEBUG_LEVEL >= RESPONSE_DEBUG;
        return $response;
      }
    } elsif (exists $self->{mock}->{$request}) {
      my $response = $self->{mock}->{$request};

      if (ref($response) eq 'CODE') {
        $response = $response->($self, $request) . $self->{suffix};
      }

      $response .= $self->{suffix};
      $self->debug('Command response: %s', $response) if DEBUG_LEVEL >= RESPONSE_DEBUG;
      return $response;
    } else {
      my ($command) = split(/\s+/, $request, 2);

      if (exists $self->{mock}->{$command}) {
        my $response = $self->{mock}->{$command};

        if (ref($response) eq 'CODE') {
          $response = $response->($self, $request) . $self->{suffix};
          $self->debug('Command response: %s', $response) if DEBUG_LEVEL >= RESPONSE_DEBUG;
          return $response;
        }
      }
    }
  }

  my $response = 'ERR'. $self->{suffix};
  $self->debug('Command response: %s', $response) if DEBUG_LEVEL >= RESPONSE_DEBUG;
  return $response;
}

sub addSetpointMock {
  my ($self, $command, %attr) = @_;
  my $format = '%.'. ($attr{precision} // 2) .'f';
  my $default = sprintf($format, $attr{default} // 1.5);

  $self->addMock($command, sub {
    my ($self, $request) = @_;

    my ($cmd, $value) = split(/\s+/, $request, 2);

    # Apply appropriate precision
    $value = sprintf($format, $value);

    my $error = undef;

    # Check for maximum value
    if (exists $attr{maximum} && $value > $attr{maximum}) {
      $error = 1;
    }

    # Check for a validation function
    if (!$error && exists $attr{validate}) {
      $error = ! $attr{validate}->($self, $request, $value, \%attr);
    }

    if ($error) {
      # Check for no explicit error requirement
      if ($attr{noerror}) {
        return $self->{suffix} // '';
      }
      
      return 'ERR'. $self->{suffix};
    }

    $self->{setpoint}->{$command} = sprintf($format, $value);

    return $self->suffix // '';
  });

  $self->addMock("$command?", sub {
    my ($self, $request) = @_;

    return ($self->{setpoint}->{$command} // $default) . $self->{suffix};
  });
}

1;