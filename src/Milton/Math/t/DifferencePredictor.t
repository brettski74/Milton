#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use Milton::Math::DifferencePredictor;

subtest 'zeroth order predictor' => sub {
  my $p = Milton::Math::DifferencePredictor->new(0);

  is($p->predict(0), U(), 'Uninitialized predict(0) returns undef');
  is($p->predict(1), U(), 'Uninitialized predict(1) returns undef');
  is($p->predict(2), U(), 'Uninitialized predict(2) returns undef');

  is($p->last(0), U(), 'Uninitialized last(0) returns undef');
  is($p->last(1), U(), 'Uninitialized last(1) returns undef');
  is($p->last(2), U(), 'Uninitialized last(2) returns undef');

  $p->next(10);
  is($p->predict(0), 10, 'predict(0) returns value');
  is($p->predict(1), 10, 'predict(1) returns value');
  is($p->predict(2), 10, 'predict(2) returns value');
  is($p->last(0), 10, 'last(0) returns value');
  is($p->last(1), U(), 'last(1) limited by order');
  is($p->last(2), U(), 'last(2) limited by order');

  $p->next(14);
  is($p->predict(0), 14, 'predict(0) returns value');
  is($p->predict(1), 14, 'predict(1) returns value');
  is($p->predict(2), 14, 'predict(2) returns value');
  is($p->last(0), 14, 'last(0) returns value');
  is($p->last(1), U(), 'last(1) limited by order');
  is($p->last(2), U(), 'last(2) limited by order');

  $p->next(18);
  is($p->predict(0), 18, 'predict(0) returns value');
  is($p->predict(1), 18, 'predict(1) returns value');
  is($p->predict(2), 18, 'predict(2) returns value');
  is($p->last(0), 18, 'last(0) returns value');
  is($p->last(1), U(), 'last(1) limited by order');
  is($p->last(2), U(), 'last(2) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), U(), 'difference limited by order');
};

subtest 'first order predictor' => sub {
  my $p = Milton::Math::DifferencePredictor->new(1);

  is($p->predict(0), U(), 'Uninitialized predictor returns undef');
  is($p->predict(1), U(), 'Uninitialized predictor returns undef');
  is($p->predict(2), U(), 'Uninitialized predictor returns undef');

  is($p->last(0), U(), 'Uninitialized predictor returns undef');
  is($p->last(1), U(), 'Uninitialized predictor returns undef');
  is($p->last(2), U(), 'Uninitialized predictor returns undef');

  $p->next(10);
  is($p->predict(0), 10, 'predict(0) returns value');
  is($p->predict(1), 20, 'predict(1) returns value');
  is($p->predict(2), 30, 'predict(2) returns value');
  is($p->last(0), 10, 'last(0) returns value');

  $p->next(14);
  is($p->predict(0), 14, 'predict(0) returns value');
  is($p->predict(1), 18, 'predict(1) returns value');
  is($p->predict(2), 22, 'predict(2) returns value');
  is($p->last(0), 14, 'last(0) returns value');
  is($p->last(1), 10, 'last(1) returns value');
  is($p->last(2), U(), 'last(2) limited by order');

  $p->next(17);
  is($p->predict(0), 17, 'predict(0) returns value');
  is($p->predict(1), 20, 'predict(1) returns value');
  is($p->predict(2), 23, 'predict(2) returns value');
  is($p->last(0), 17, 'last(0) returns value');
  is($p->last(1), 14, 'last(1) returns value');
  is($p->last(2), U(), 'last(2) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 3, 'first difference');
  is($p->difference(2), U(), 'second difference limited by order');

  $p->next($p->predict(1));
  is($p->predict(0), 20, 'Updating with prediction');
  is($p->predict(1), 23, 'predict(1) after updating with prediction');
  is($p->predict(2), 26, 'predict(2) after updating with prediction');
  is($p->last(0), 20, 'last(0) after updating with prediction');
  is($p->last(1), 17, 'last(1) after updating with prediction');
  is($p->last(2), U(), 'last(2) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 3, 'first difference');
  is($p->difference(2), U(), 'second difference limited by order');

  $p->next(17);
  $p->next(11);
  is($p->predict(0), 11, 'predict(0) returns value');
  is($p->predict(1), 5, 'predict(1) returns value');
  is($p->predict(2), -1, 'predict(2) returns value');
  is($p->last(0), 11, 'last(0) returns value');
  is($p->last(1), 17, 'last(1) returns value');
  is($p->last(2), U(), 'last(2) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), -6, 'first difference');
  is($p->difference(2), U(), 'second difference limited by order');

  $p->next($p->predict(1));

  is($p->predict(0), 5, 'predict(0) after updating with prediction');
  is($p->predict(1), -1, 'predict(1) after updating with prediction');
  is($p->predict(2), -7, 'predict(2) after updating with prediction');
  is($p->last(0), 5, 'last(0) after updating with prediction');
  is($p->last(1), 11, 'last(1) after updating with prediction');
  is($p->last(2), U(), 'last(2) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), -6, 'first difference');
  is($p->difference(2), U(), 'second difference limited by order');
};

subtest 'second order predictor' => sub {
  my $p = Milton::Math::DifferencePredictor->new(2);

  is($p->predict(0), U(), 'Uninitialized predictor returns undef');
  is($p->predict(1), U(), 'Uninitialized predictor returns undef');
  is($p->predict(2), U(), 'Uninitialized predictor returns undef');

  is($p->last(0), U(), 'Uninitialized predictor returns undef');
  is($p->last(1), U(), 'Uninitialized predictor returns undef');
  is($p->last(2), U(), 'Uninitialized predictor returns undef');

  $p->next(10);
  is($p->predict(0), 10, 'predict(0) returns value');
  is($p->predict(1), 30, 'predict(1) returns value');
  is($p->predict(2), 60, 'predict(2) returns value');
  is($p->last(0), 10, 'last(0) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  $p->next(14);
  is($p->predict(0), 14, 'predict(0) returns value');
  is($p->predict(1), 12, 'predict(1) returns value');
  is($p->predict(2), 4, 'predict(2) returns value');
  is($p->last(0), 14, 'last(0) returns value');
  is($p->last(1), 10, 'last(1) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  $p->next(17);
  is($p->predict(0), 17, 'predict(0) returns value');
  is($p->predict(1), 19, 'predict(1) returns value');
  is($p->predict(2), 20, 'predict(2) returns value');
  is($p->predict(3), 20, 'predict(3) returns value');
  is($p->last(0), 17, 'last(0) returns value');
  is($p->last(1), 14, 'last(1) returns value');
  is($p->last(2), 10, 'last(2) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 3, '1st order difference');
  is($p->difference(2), -1, '2nd order difference');
  is($p->difference(3), U(), '3rd order difference limited by order');

  $p->next($p->predict(1));
  is($p->predict(0), 19, 'predict(0) after updating with prediction');
  is($p->predict(1), 20, 'predict(1) after updating with prediction');
  is($p->predict(2), 20, 'predict(2) after updating with prediction');
  is($p->predict(3), 19, 'predict(3) after updating with prediction');
  is($p->last(0), 19, 'last(0) after updating with prediction');
  is($p->last(1), 17, 'last(1) after updating with prediction');
  is($p->last(2), 14, 'last(2) after updating with prediction');
  is($p->last(3), U(), 'last(3) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 2, '1st order difference');
  is($p->difference(2), -1, '2nd order difference');
  is($p->difference(3), U(), '3rd order difference limited by order');

  $p->next(14)->next(17)->next(18);
  is($p->predict(0), 18, 'predict(0) returns value');
  is($p->predict(1), 17, 'predict(1) returns value');
  is($p->predict(2), 14, 'predict(2) returns value');
  is($p->predict(3), 9, 'predict(3) returns value');
  is($p->last(0), 18, 'last(0) returns value');
  is($p->last(1), 17, 'last(1) returns value');
  is($p->last(2), 14, 'last(2) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 1, '1st order difference');
  is($p->difference(2), -2, '2nd order difference');
  is($p->difference(3), U(), '3rd order difference limited by order');

  $p->next(18);
  is($p->predict(0), 18, 'predict(0) returns value');
  is($p->predict(1), 17, 'predict(1) returns value');
  is($p->predict(2), 15, 'predict(2) returns value');
  is($p->predict(3), 12, 'predict(3) returns value');
  is($p->last(0), 18, 'last(0) returns value');
  is($p->last(1), 18, 'last(1) returns value');
  is($p->last(2), 17, 'last(2) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), 0, '1st order difference');
  is($p->difference(2), -1, '2nd order difference');
  is($p->difference(3), U(), '3rd order difference limited by order');
  
  $p->next($p->predict(1));
  $p->next($p->predict(1));
  is($p->predict(0), 15, 'predict(0) returns value');
  is($p->predict(1), 12, 'predict(1) returns value');
  is($p->predict(2), 8, 'predict(2) returns value');
  is($p->predict(3), 3, 'predict(3) returns value');
  is($p->last(0), 15, 'last(0) returns value');
  is($p->last(1), 17, 'last(1) returns value');
  is($p->last(2), 18, 'last(2) returns value');
  is($p->last(3), U(), 'last(3) limited by order');

  is($p->difference(0), U(), '0th order difference is undefined');
  is($p->difference(1), -2, '1st order difference');
  is($p->difference(2), -1, '2nd order difference');
  is($p->difference(3), U(), '3rd order difference limited by order');
};

done_testing;
