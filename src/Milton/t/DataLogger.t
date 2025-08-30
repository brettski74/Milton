#!/usr/bin/perl

use strict;
use warnings;
use lib '.';
use Test2::V0;
use Milton::DataLogger;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use IO::Capture::Stdout;

# Create a temporary directory for log files
my $tmpdir = tempdir(CLEANUP => 1);

# Test config
my $config = { enabled  => 1
             , command  => 'testcmd'
             , filename => File::Spec->catfile($tmpdir, 'log-%c-%d.csv')
             , columns  => [ { key => 'now',   format => 'd' }
                           , { key => 'stage' }
                           , { key => 'temp',   format => '.2f' }
                           , { key => 'power',  format => 'd' }
                           , { key => 'last.power', format => 'd' }
                           ]
             };

note('Testing DataLogger construction and header');
my $logger = Milton::DataLogger->new($config);
isa_ok($logger, 'Milton::DataLogger');
my $expected_prefix = File::Spec->catfile($tmpdir, 'log-testcmd-');
like($logger->logFilename, qr/^\Q$expected_prefix\E\d{8}-\d{6}\.csv$/,'Filename expanded with command and date in tempdir');
my @cols = $logger->logColumns;
is(\@cols, [qw(now stage temp power last.power)], 'Columns match config');

# Check that the file exists and header is correct
note('Test log file name is '. $logger->logFilename);
ok(-e $logger->logFilename, 'Log file created');
$logger->writeHeader;

note('Testing logging rows');
$logger->log({ now => 1, stage => 'A', temp => 25.12345, power => 100, last => { power => 90 } });
$logger->log({ now => 2, stage => 'B', temp => 30.3398762, power => 110, last => { power => 100 } });
$logger->close;

open my $fh, '<', $logger->logFilename or die $!;
my $header = <$fh>; chomp $header;
is($header, 'now,stage,temp,power,last.power', 'Header line correct');
my $row1 = <$fh>; chomp $row1;
my $row2 = <$fh>; chomp $row2;
is($row1, '1,A,25.12,100,90', 'First row logged correctly');
is($row2, '2,B,30.34,110,100', 'Second row logged correctly');
close $fh;

note('Testing Null logger');
my $null_logger = Milton::DataLogger->new({ enabled => 0 });
isa_ok($null_logger, 'Milton::DataLogger::Null');
$null_logger->log({ foo => 1 }); # should do nothing
is($null_logger->logFilename, undef, 'Null logger returns undef for filename');
is([$null_logger->logColumns], [], 'Null logger returns empty list for columns');

# Test hold, flush, and release methods
note('Testing hold, flush, and release methods');

# Create a logger with tee enabled
my $tee_config = { enabled  => 1
                 , command  => 'testcmd'
                 , filename => File::Spec->catfile($tmpdir, 'tee-log-%c-%d.csv')
                 , tee      => 1
                 , columns  => [ { key => 'now', format => 'd' }
                               , { key => 'stage' }
                               , { key => 'temp', format => '.2f' }
                               ]
                 };

my $tee_logger = Milton::DataLogger->new($tee_config);
$tee_logger->writeHeader;

# Test normal logging without hold (should output to STDOUT)
my $capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->log({ now => 1, stage => 'A', temp => 25.12 });
$capture->stop();
my $output = $capture->read();
like($output, qr/1,A,25\.12/, 'Normal logging outputs to STDOUT when tee enabled');

# Test hold functionality
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->hold();
$tee_logger->log({ now => 2, stage => 'B', temp => 30.34 });
$tee_logger->log({ now => 3, stage => 'C', temp => 35.56 });
$capture->stop();
$output = $capture->read();
is($output, undef, 'Hold prevents output to STDOUT');

# Test flush functionality
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->flush();
$capture->stop();
$output = $capture->read();
chomp $output;
is($output, '2,B,30.34', 'Flush outputs buffered data - first line');
$output = $capture->read();
chomp $output;
is($output, '3,C,35.56', 'Flush outputs buffered data - second line');

# Test that hold is still active after flush
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->log({ now => 4, stage => 'D', temp => 40.78 });
$capture->stop();
$output = $capture->read();
is($output, undef, 'Hold still active after flush');

# Test release functionality
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->release();
$capture->stop();
$output = $capture->read();
chomp $output;
is($output, '4,D,40.78', 'Release outputs remaining buffered data');

# Test that logging works normally after release
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->log({ now => 5, stage => 'E', temp => 45.90 });
$capture->stop();
$output = $capture->read();
chomp $output;
is($output, '5,E,45.90', 'Normal logging resumes after release');

# Test multiple hold/release cycles
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->hold();
$tee_logger->log({ now => 6, stage => 'F', temp => 50.12 });
$tee_logger->log({ now => 7, stage => 'G', temp => 55.34 });
$tee_logger->release();
$capture->stop();
$output = $capture->read();
chomp $output;
is($output, '6,F,50.12', 'Multiple hold/release cycles work correctly - first line');
$output = $capture->read();
chomp $output;
is($output, '7,G,55.34', 'Multiple hold/release cycles work correctly - second line');

# Test flush without hold (should do nothing)
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->flush();
$capture->stop();
$output = $capture->read();
is($output, undef, 'Flush does nothing when not holding');

# Test hold without tee (should not affect file logging)
my $no_tee_config = { enabled  => 1
                    , command  => 'testcmd'
                    , filename => File::Spec->catfile($tmpdir, 'no-tee-log-%c-%d.csv')
                    , tee      => 0
                    , columns  => [ { key => 'now', format => 'd' }
                                  , { key => 'stage' }
                                  , { key => 'temp', format => '.2f' }
                                  ]
                    };

my $no_tee_logger = Milton::DataLogger->new($no_tee_config);
$no_tee_logger->writeHeader;
$no_tee_logger->hold();
$no_tee_logger->log({ now => 8, stage => 'H', temp => 60.56 });
$no_tee_logger->release();
$no_tee_logger->close();

# Verify file was still written correctly
open $fh, '<', $no_tee_logger->logFilename or die $!;
<$fh>; # Skip header
my $row = <$fh>; chomp $row;
is($row, '8,H,60.56', 'File logging works correctly even with hold when tee disabled');
close $fh;

# Test that Null logger methods don't crash
$null_logger->hold();
$null_logger->flush();
$null_logger->release();
pass('Null logger hold/flush/release methods do not crash');

# Test edge cases
note('Testing edge cases');

# Test multiple flushes
$tee_logger->hold();
$tee_logger->log({ now => 10, stage => 'J', temp => 70.90 });
$capture = IO::Capture::Stdout->new();
$capture->start();
$tee_logger->flush();
$tee_logger->flush(); # Second flush should do nothing
$capture->stop();
$output = $capture->read();
chomp $output;
is($output, '10,J,70.90', 'Multiple flushes work correctly (second flush does nothing)');

$tee_logger->close();

done_testing(); 
