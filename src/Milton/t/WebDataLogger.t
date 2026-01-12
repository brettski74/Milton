#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;
use Milton::WebDataLogger;
use IO::Capture::Stdout;
use File::Spec;
use File::Temp qw(tempdir);

my $tmpdir = tempdir(CLEANUP => 1);

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

# Test consoleProcess method
subtest 'consoleProcess method' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $msg = "Hello world\n";
  is($logger->consoleProcess('DATA', $msg), "DATA: Hello world\n", 'DATA prefix');
  is($logger->consoleProcess('INFO', $msg), "INFO: Hello world\n", 'INFO prefix');
  is($logger->consoleProcess('WARN', $msg), "WARN: Hello world\n", 'WARN prefix');
  is($logger->consoleProcess('DEBUG', $msg), "DEBUG: Hello world\n", 'DEBUG prefix');

  $msg = "This is the first line\nThis is the second line\r\nThis is the third line\n";
  is($logger->consoleProcess('DATA', $msg), "DATA: This is the first line\nDATA: This is the second line\nDATA: This is the third line\n", 'multi-line DATA');
  is($logger->consoleProcess('INFO', $msg), "INFO: This is the first line\nINFO: This is the second line\nINFO: This is the third line\n", 'multi-line INFO');
  is($logger->consoleProcess('WARN', $msg), "WARN: This is the first line\nWARN: This is the second line\nWARN: This is the third line\n", 'multi-line WARN');
  is($logger->consoleProcess('DEBUG', $msg), "DEBUG: This is the first line\nDEBUG: This is the second line\nDEBUG: This is the third line\n", 'multi-line DEBUG');
};

# Test info method
subtest 'info method' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->info("Test info message");
  $logger->info("Another info message\n");
  $logger->info("Multi-line\ninfo\nmessage");
  $capture->stop();
  my @output = $capture->read();
  
  is(join('', @output), "INFO: Test info message\nINFO: Another info message\nINFO: Multi-line\nINFO: info\nINFO: message\n", 'info method output');
};

# Test warning method
subtest 'warning method' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->warning("Test warning message");
  $logger->warning("Another warning message\n");
  $logger->warning("Multi-line\nwarning\nmessage");
  $capture->stop();
  my @output = $capture->read();
  
  is(join('', @output), "WARN: Test warning message\nWARN: Another warning message\nWARN: Multi-line\nWARN: warning\nWARN: message\n", 'warning method output');
};

# Test debug method
subtest 'debug method' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->debug("Test debug message level %d", 1);
  $logger->debug("Test debug message level %d", 5);
  $logger->debug("Test debug message level %d", 10);
  $logger->debug("Multi-line\ndebug\nmessage");
  $capture->stop();
  my @output = $capture->read();
  my $this_test = __FILE__;
  my $line1 = __LINE__ - 7;
  my $line2 = __LINE__ - 7;
  my $line3 = __LINE__ - 7;
  my $line4 = __LINE__ - 7;
  
  is(join('', @output), <<"EOS", 'debug method output');
DEBUG: $this_test:$line1: Test debug message level 1
DEBUG: $this_test:$line2: Test debug message level 5
DEBUG: $this_test:$line3: Test debug message level 10
DEBUG: $this_test:$line4: Multi-line
DEBUG: debug
DEBUG: message
EOS
};

# Test log method with tee enabled
subtest 'log method with tee enabled' => sub {
  my $logger = Milton::WebDataLogger->new({
    enabled => 1,
    filename => File::Spec->catfile($tmpdir, 'test_log.csv'),
    tee => 1,
    columns => [
      { key => 'temperature', format => '.2f' },
      { key => 'power', format => '.1f' }
    ]
  });
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  
  my $status = {
    temperature => 25.5,
    power => 100.0
  };
  
  $logger->log($status);
  $capture->stop();
  my @output = $capture->read();
  
  is(join('', @output), "DATA: 25.50,100.0\n", 'log method with tee enabled');
  
  # Clean up
  $logger->close;
};

# Test mixed output types
subtest 'mixed output types' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->info("Starting operation");
  $logger->warning("Temperature is high");
  $logger->info("Operation complete");
  $capture->stop();
  my @output = $capture->read();
  
  is(join('', @output), "INFO: Starting operation\nWARN: Temperature is high\nINFO: Operation complete\n", 'mixed output types');
};

# Test edge cases
subtest 'edge cases' => sub {
  my $logger = Milton::WebDataLogger->new($config);
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->info("");  # Empty message
  $logger->info("Message with\n\nmultiple\n\n\nnewlines");
  $logger->info("Message with\r\nWindows\r\nline endings");
  $capture->stop();
  my @output = $capture->read();
  
  is(join('', @output), "INFO: \nINFO: Message with\nINFO: \nINFO: multiple\nINFO: \nINFO: \nINFO: newlines\nINFO: Message with\nINFO: Windows\nINFO: line endings\n", 'edge cases');
};

subtest 'logger data header' => sub {
  $config->{tee} = 1;
  my $logger = Milton::WebDataLogger->new($config);

  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $logger->writeHeader;
  $capture->stop();
  my @output = $capture->read();

  is(join('', @output), "HEAD: now,stage,temp,power,last.power\n", 'logger data header');
};

done_testing;
