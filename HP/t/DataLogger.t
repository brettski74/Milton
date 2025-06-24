#!/usr/bin/perl

use strict;
use warnings;
use lib '.';
use Test2::V0;
use HP::DataLogger;
use File::Temp qw(tempfile tempdir);
use File::Spec;

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
my $logger = HP::DataLogger->new($config);
isa_ok($logger, 'HP::DataLogger');
my $expected_prefix = File::Spec->catfile($tmpdir, 'log-testcmd-');
like($logger->logFilename, qr/^\Q$expected_prefix\E\d{8}-\d{6}\.csv$/,'Filename expanded with command and date in tempdir');
my @cols = $logger->logColumns;
is(\@cols, [qw(now stage temp power last.power)], 'Columns match config');

# Check that the file exists and header is correct
note('Test log file name is '. $logger->logFilename);
ok(-e $logger->logFilename, 'Log file created');

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
my $null_logger = HP::DataLogger->new({ enabled => 0 });
isa_ok($null_logger, 'HP::DataLogger::Null');
$null_logger->log({ foo => 1 }); # should do nothing
is($null_logger->logFilename, undef, 'Null logger returns undef for filename');
is([$null_logger->logColumns], [], 'Null logger returns empty list for columns');

done_testing(); 