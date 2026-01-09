#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use lib '.';

use Test2::V0;

use Milton::Interface::SCPICommon;
use Milton::Interface::Utils::t::SCPIMock;
use Data::Dumper;

subtest 'Standard Output Commands' => sub {
  my $scpi = Milton::Interface::Utils::t::SCPIMock->new();
  $scpi->addSetpointMock('VOLT', precision => 2, default => 1.5);
  $scpi->addSetpointMock('CURR', precision => 3, default => 1.25);
  $scpi->addMock('OUTP?', 'ON');
  isa_ok($scpi, 'Milton::Interface::SCPICommon');

  ok($scpi->_is_on, 'Output should be on (ON)') || diag(Dumper({ request => $scpi->checkRequestHistory, response => $scpi->checkResponseHistory }));

  $scpi->addMock('OUTP?', 'OFF');
  ok(!$scpi->_is_on, 'Output should be off (OFF)') || diag(Dumper({ request => $scpi->checkRequestHistory, response => $scpi->checkResponseHistory }));

  $scpi->addMock('OUTP?', 1);
  ok($scpi->_is_on, 'Output should be on (1)') || diag(Dumper({ request => $scpi->checkRequestHistory, response => $scpi->checkResponseHistory }));

  $scpi->addMock('OUTP?', 0);
  ok(!$scpi->_is_on, 'Output should be off (0)') || diag(Dumper({ request => $scpi->checkRequestHistory, response => $scpi->checkResponseHistory }));

  $scpi->on(1);
  is($scpi->checkRequestHistory, 'OUTP ON', 'Should have sent OUTP ON command');
  $scpi->on(0);
  is($scpi->checkRequestHistory, 'OUTP OFF', 'Should have sent OUTP OFF command');

};

subtest 'SPD1305X Output Commands' => sub {
  my $scpi = Milton::Interface::Utils::t::SCPIMock->new({ 'on-off-query' => 'SYST:STAT?'
                                                        , 'on-off-bitmask' => 0x10
                                                        , 'on-off-command' => 'OUTP CH1,'
                                                        }
                                                      );
  $scpi->addSetpointMock('VOLT', precision => 2, default => 1.5);
  $scpi->addSetpointMock('CURR', precision => 3, default => 1.25);

  ok(!$scpi->_is_on, 'Output shoudl be off (default mock)');

  foreach my $response (qw(0 0x0 0x00 0x22 0x41 0x6e)) {
    $scpi->addMock('SYST:STAT?', $response);
    ok(!$scpi->_is_on, "Output should be off ($response)");
  }

  foreach my $response (qw(16 0x10 0x35 0x7f 51)) {
    $scpi->addMock('SYST:STAT?', $response);
    ok($scpi->_is_on, "Output should be on ($response)");
  }
};

done_testing();

1;