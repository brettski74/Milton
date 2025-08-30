#!/usr/bin/perl

use Test2::V0;
use Milton::Math::SimpleLinearRegression;

my $EPS = 0.000001;

subtest 'simple linear regression' => sub {
  my $regression = Milton::Math::SimpleLinearRegression->new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

  is($regression->gradient, 1, 'gradient is 1');
  is($regression->intercept, 1, 'intercept is 1');
  is($regression->xsum, 25, 'xsum is 55');
  is($regression->ysum, 30, 'ysum is 55');
  is($regression->x2sum, 165, 'x2sum is 385');
  is($regression->xysum, 190, 'xysum is 330');
  is($regression->n, 5, 'n is 5');

  $regression->addData(1.5, 2.3, 5.7, 6.6, 7.3, 8.6, 19.6, 19.8);

  is($regression->gradient, float(0.963441724, tolerance => $EPS), 'gradient');
  is($regression->intercept, float(1.151177127, tolerance => $EPS), 'intercept');
  is($regression->xsum, 59.1, 'xsum');
  is($regression->ysum, 67.3, 'ysum');
  is($regression->x2sum, 637.19, 'x2sum');
  is($regression->xysum, 681.93, 'xysum');
  is($regression->n, 9, 'n');
};

subtest 'hash dat' => sub {
  my $slr = Milton::Math::SimpleLinearRegression->new;
  $slr->addHashData('resistance', 'temperature'
                 , { resistance => 1.65114686252212, temperature => 81.5533333333333 }
                 , { resistance => 1.78401900416016, temperature => 106.166666666667 }
                 , { resistance => 1.91584592543491, temperature => 129.973333333333 }
                 , { resistance => 2.1415380665979, temperature => 170.426666666667 }
                 , { resistance => 2.31866051553867, temperature => 202.133333333333 }
                 , { resistance => 2.42418705863328, temperature => 219.793333333333 }
                 );

  is($slr->gradient, float(179.056381171275, tolerance => $EPS), 'gradient');
  is($slr->intercept, float(-213.463219976399, tolerance => $EPS), 'intercept');
  is($slr->xsum, 12.235397432887, 'xsum');
  is($slr->ysum, 910.046666666666, 'ysum');
  is($slr->x2sum, 25.4185301510778, 'x2sum');
  is($slr->xysum, 1939.5426898299, 'xysum');
  is($slr->n, 6, 'n');
};

subtest 'edge cases' => sub {
  my $slr = Milton::Math::SimpleLinearRegression->new(5,10);
  is($slr->gradient, U(), 'gradient');
  is($slr->intercept, U(), 'intercept');
  is($slr->xsum, 5, 'xsum');
  is($slr->ysum, 10, 'ysum');
  is($slr->x2sum, 25, 'x2sum');
  is($slr->xysum, 50, 'xysum');
  is($slr->n, 1, 'n');

  $slr = Milton::Math::SimpleLinearRegression->new;
  is($slr->gradient, U(), 'gradient');
  is($slr->intercept, U(), 'intercept');
  is($slr->xsum, 0, 'xsum');
  is($slr->ysum, 0, 'ysum');
  is($slr->x2sum, 0, 'x2sum');
  is($slr->xysum, 0, 'xysum');
  is($slr->n, 0, 'n');
};

done_testing;
