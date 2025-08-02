#!/usr/bin/env perl

use strict;
use warnings qw(all -uninitialized);
use Test2::V0;
use PowerSupplyControl::Math::LowPassFilter;

# Tolerance for floating point comparisons
my $EPS = 1e-6;

subtest 'Basic static filtering' => sub {
  my $f= PowerSupplyControl::Math::LowPassFilter->new(tau => 9, period => 1);
    
  isa_ok($f, 'PowerSupplyControl::Math::LowPassFilter');
  is($f->last, U(), "Last value is initially undefined");
  is($f->next(5), 5, "5 - First value returned as-is");
  is($f->last, 5, "Last value correct");
  is($f->next(6), float(5.1, tolerance => $EPS), "6 - filter output correct");
  is($f->last, float(5.1, tolerance => $EPS), "Last value correct");
  is($f->next(7), float(5.29, tolerance => $EPS), "7 - filter output correct");
  is($f->last, float(5.29, tolerance => $EPS), "Last value correct");
  is($f->next(8), float(5.561, tolerance => $EPS), "8 - filter output correct");
  is($f->last, float(5.561, tolerance => $EPS), "Last value correct");
  is($f->next(9), float(5.9049, tolerance => $EPS), "9 - filter output correct");
  is($f->last, float(5.9049, tolerance => $EPS), "Last value correct");
};

subtest 'Dynamic filtering' => sub {
  my $f = PowerSupplyControl::Math::LowPassFilter->new(tau => 9, period => 1);

  is($f->last, U(), "Last value is initially undefined");
  is($f->next(5,1.1), 5, "5 - First value returned as-is");
  is($f->last, 5, "Last value correct");
  is($f->next(6,8.5), float(5.105263158, tolerance => $EPS), "6,8.5 - filter output correct");
  is($f->last, float(5.105263158, tolerance => $EPS), "Last value correct");
  is($f->next(7,8), float(5.315789474, tolerance => $EPS), "7,8 - filter output correct");
  is($f->last, float(5.31578947429, tolerance => $EPS), "Last value correct");
  is($f->next(8,7.5), float(5.631578947, tolerance => $EPS), "8,7.5 - filter output correct");
  is($f->last, float(5.631578947, tolerance => $EPS), "Last value correct");
  is($f->next(9), float(6.027863777, tolerance => $EPS), "9 - filter output correct");
  is($f->last, float(6.027863777, tolerance => $EPS), "Last value correct");
};

subtest 'Constructor validation' => sub {
  
  like(dies { PowerSupplyControl::Math::LowPassFilter->new(period => 0.1); }
     , qr/tau is a mandatory parameter/, 'Requires tau'
     );

  like(dies { PowerSupplyControl::Math::LowPassFilter->new(tau => 1.0); }
     , qr/period is a mandatory parameter/, 'Requires period'
     );

  like(dies { PowerSupplyControl::Math::LowPassFilter->new(tau => -1, period => 1); } 
     , qr/tau must be non-negative/, 'Requires non-negative tau'
     );

  like(dies { PowerSupplyControl::Math::LowPassFilter->new(tau => 1, period => 0); } 
     , qr/period must be positive/, 'Requires non-zero period'
     );

  like(dies { PowerSupplyControl::Math::LowPassFilter->new(tau => 1, period => -2); } 
     , qr/period must be positive/, 'Requires positive period'
     );
};

# Test 7: Edge cases - zero tau
subtest 'Edge cases - zero tau' => sub {
    
  my $f = PowerSupplyControl::Math::LowPassFilter->new(tau => 0.0, period => 0.1);

  is($f->last, U(), "Last value is initially undefined");
  is($f->next(10), 10, "10 - First value is 10");
  is($f->next(13), 13, "13 - Second value is 13");
  is($f->next(9), 9, "9 - Third value is 9");
  is($f->next(3), 3, "3 - Fourth value is 3");
  is($f->next(53), 53, "53 - Fifth value is 53");
};

done_testing(); 