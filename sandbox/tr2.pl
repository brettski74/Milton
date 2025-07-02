#!/usr/bin/perl

use Statistics::Regression;

my $reg = Statistics::Regression->new('sample regression', [ 'const', 'someX', 'someY' ] );

# Add data points
$reg->include(2.0, [ 1.0, 3.0, -1.0 ]);
$reg->include(2.0, [ 1.0, 5.0, 2.0 ]);
$reg->include(20.0, [ 1.0, 31.0, 0.0 ]);
$reg->include(15.0, [ 1.0, 11.0, 2.0 ]);

$reg->print();

