package Milton::DataLoader;

use strict;
use warnings;

use IO::File;

sub new {
    my ($class, $filename) = @_;
    my $self = {};
    bless $self, $class;

    $self->readDate($filename);

    $self->{filename} = $filename;
    $self->{file} = IO::File->new($filename, 'r');

    return $self;
}