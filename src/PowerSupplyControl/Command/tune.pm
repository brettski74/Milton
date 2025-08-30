package PowerSupplyControl::Command::tune;

use base 'PowerSupplyControl::Command::reflow';

use Carp qw(croak);

use PowerSupplyControl::Controller::HybridPI;

sub new {
  my ($class, $config, $interface, $controller, @args) = @_;

  my $self = $class->SUPER::new($config, $interface, $controller, @args);

  $self->{tune} //= $config->getPath('controller', 'predictor');
  $self->{ctrltune} //= $config->getPath('controller');

  return $self;
}

sub options {
  my ($self) = @_;
  my @options = $self->SUPER::options;
  push @options, qw( ctrltune=s );
  return @options;
}

sub postprocess {
  my ($self, $status, $history) = @_;

  my $config = $self->{config};
  my $controller = PowerSupplyControl::Controller::HybridPI->new({ predictor => { package => 'PowerSupplyControl::Predictor::DoubleLPFPower' }}
                                                               , $self->{interface}
                                                               );
  $self->{controller} = $controller;

  $self->SUPER::postprocess($status, $history);

  my $tuned = $controller->tune($history, parallel => $config->{tuning}->{parallel});

  foreach my $key (keys %{$config->{controller}}) {
    my $path = $config->getPath('controller', $key);
    if (defined $path) {
      $tuned->{$key} = "!include $path";
    } elsif (!defined $tuned->{$key}) {
      $tuned->{$key} = $config->{controller}->{$key};
    }
  }

  my $fh = $self->replaceFile($self->{ctrltune}) || croak "Failed to open file $self->{ctrltune} for writing";
  my $ypp = $config->getYamlParser();
  $fh->print($ypp->dump_string($tuned));
  $fh->close();

  return;
}

1;