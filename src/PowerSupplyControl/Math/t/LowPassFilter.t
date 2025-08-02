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
  is($f->next(5,tau => 1.1), 5, "5,tau=>1.1 - First value returned as-is");
  is($f->last, 5, "Last value correct");
  is($f->next(6,tau => 8.5), float(5.105263158, tolerance => $EPS), "6,tau=>8.5 - filter output correct");
  is($f->last, float(5.105263158, tolerance => $EPS), "Last value correct");
  is($f->next(7,tau => 8), float(5.315789474, tolerance => $EPS), "7,tau=>8 - filter output correct");
  is($f->last, float(5.31578947429, tolerance => $EPS), "Last value correct");
  is($f->next(8,tau => 7.5), float(5.631578947, tolerance => $EPS), "8,tau=>7.5 - filter output correct");
  is($f->last, float(5.631578947, tolerance => $EPS), "Last value correct");
  is($f->next(9), float(6.027863777, tolerance => $EPS), "9 - filter output correct");
  is($f->last, float(6.027863777, tolerance => $EPS), "Last value correct");
  is($f->next(10, period => 2), float(6.864102982, tolerance => $EPS), "10,period=>2 - filter output correct");
};

subtest 'Constructor validation' => sub {
  
  like(dies { PowerSupplyControl::Math::LowPassFilter->new(period => 0.1); }
     , qr/tau must be non-negative/, 'Requires tau'
     );

  like(dies { PowerSupplyControl::Math::LowPassFilter->new(tau => 1.0); }
     , qr/period must be positive/, 'Requires period'
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

subtest 'Edge cases - zero tau' => sub {
    
  my $f = PowerSupplyControl::Math::LowPassFilter->new(tau => 0.0, period => 0.1);

  is($f->last, U(), "Last value is initially undefined");
  is($f->next(10), 10, "10 - First value is 10");
  is($f->next(13), 13, "13 - Second value is 13");
  is($f->next(9), 9, "9 - Third value is 9");
  is($f->next(3), 3, "3 - Fourth value is 3");
  is($f->next(53), 53, "53 - Fifth value is 53");
};

subtest 'Reset' => sub {
  my $f = PowerSupplyControl::Math::LowPassFilter->new(tau => 9, period => 1);

  is($f->last, U(), "Last value is initially undefined");
  is($f->next(10), 10, "10 - First value is 10");
  is($f->reset(15), 15, 'Reset to 15');
  is($f->last, 15, 'Last value is 15');
  is($f->next(16), float(15.1, tolerance => $EPS), "16 - filter output correct");
  is($f->last, float(15.1, tolerance => $EPS), "Last value correct");
  
  is($f->reset(20, period => 4), 20, 'Reset to 20, period=>4');
  is($f->last, 20, 'Last value is 20');
  is($f->next(21), float(20.30769231, tolerance => $EPS), "21 - filter output correct");
  is($f->last, float(20.30769231, tolerance => $EPS), "Last value correct");

  is($f->reset(25, tau => 10), 25, 'Reset to 25, tau=>10');
  is($f->last, 25, 'Last value is 25');
  is($f->next(22), float(24.14285714, tolerance => $EPS), "22 - filter output correct");
  is($f->last, float(24.14285714, tolerance => $EPS), "Last value correct");
};

done_testing(); 