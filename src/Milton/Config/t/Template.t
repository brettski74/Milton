#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use Test2::V0;
use Milton::Config::Template;

use Milton::Config::Path qw(add_search_dir clear_search_path);
clear_search_path();
add_search_dir('t');

sub is_file {
  my ($expected, $actual, $message) = @_;
  $message //= $expected ;

  return fail("$message: expected filename not provided") if !$expected;
  return fail("$message: actual filename not provided") if !$actual;

  return fail("$message: expected file $expected not found") if !-e $expected;
  return fail("$message: actual file $actual not found") if !-e $actual;

  return fail("$message: expected file $expected not readable") if !-r $expected;
  return fail("$message: actual file $actual not readable") if !-r $actual;

  return fail("$message: expected file $expected not a file") if !-f $expected;
  return fail("$message: actual file $actual not a file") if !-f $actual;

  my $exp = IO::File->new($expected, 'r') || fail("$message: Unable to open expected file $expected for reading: $!");
  my $act = IO::File->new($actual, 'r') || fail("$message: Unable to open actual file $actual for reading: $!");

  my @exp_lines = $exp->getlines;
  my @act_lines = $act->getlines;

  $exp->close;
  $act->close;

  return is(\@exp_lines, \@act_lines, $message);
}

subtest 'test.yaml.template' => sub {
  my $template = Milton::Config::Template->new(template => 'template/test.yaml.template');
  isa_ok($template, 'Milton::Config::Template');

  my $expected_output_file = 't/template/test.yaml';
  unlink($expected_output_file);

  $template->setParameterValue(interface => 'test.yaml'
                             , 'fan-package' => 'Milton::Interface::DPS'
                             , 'fan-voltage' => 13
                             , 'fan-current' => 1.0
                             , 'fan-duration' => 600
                             , 'shutdown-on-signal' => 'false'
                             , 'enabled' => 'true'
                             );

  is($template->getParameterValue('interface'), 'test.yaml', 'Interface parameter is correct');
  is($template->getParameterValue('fan-package'), 'Milton::Interface::DPS', 'Fan package parameter is correct');
  is($template->getParameterValue('fan-voltage'), 13, 'Fan voltage parameter is correct');
  is($template->getParameterValue('fan-current'), 1.0, 'Fan current parameter is correct');
  is($template->getParameterValue('fan-duration'), 600, 'Fan duration parameter is correct');
  is($template->getParameterValue('shutdown-on-signal'), 'false', 'Shutdown on signal parameter is correct');
  is($template->getParameterValue('enabled'), 'true', 'Enabled parameter is correct');

  my $output_file = $template->render();

  ok($output_file, 'Output file is defined') || diag($template->errorString);

  is($output_file, $expected_output_file, 'Output filename is correct');

  is_file('t/template/test.yaml.expected', $output_file);
};

done_testing();
