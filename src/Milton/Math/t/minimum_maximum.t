#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Test2::V0;

use Milton::Math::Util qw(minimum maximum);

subtest 'full data minimum and maximum' => sub {
  my $values = [
    { a => 1, b => 8, c => 3 },
    { a => 4, b => 3, c => 6 },
    { a => 7, b => 4, c => 2 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 1, 'minimum a');
  is($minb, 3, 'minimum b');
  is($minc, 2, 'minimum c');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 7, 'maximum a');
  is($maxb, 8, 'maximum b');
  is($maxc, 6, 'maximum c');
};

subtest 'partial data minimum and maximum' => sub {
  my $values = [
    { a => 1, b => 4, c => 3 },
    { a => 4, c => 6 },
    { a => 7, b => 8, c => undef },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 1, 'minimum a');
  is($minb, 4, 'minimum b');
  is($minc, 3, 'minimum c');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 7, 'maximum a');
  is($maxb, 8, 'maximum b');
  is($maxc, 6, 'maximum c');
};

subtest 'single item data' => sub {
  my $values = [
    { a => 42, b => -17, c => 3.14 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 42, 'minimum a (single item)');
  is($minb, -17, 'minimum b (single item)');
  is($minc, 3.14, 'minimum c (single item)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 42, 'maximum a (single item)');
  is($maxb, -17, 'maximum b (single item)');
  is($maxc, 3.14, 'maximum c (single item)');
};

subtest 'negative numbers' => sub {
  my $values = [
    { a => -10, b => -5, c => -20 },
    { a => -3, b => -15, c => -8 },
    { a => -1, b => -2, c => -30 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, -10, 'minimum a (negative numbers)');
  is($minb, -15, 'minimum b (negative numbers)');
  is($minc, -30, 'minimum c (negative numbers)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, -1, 'maximum a (negative numbers)');
  is($maxb, -2, 'maximum b (negative numbers)');
  is($maxc, -8, 'maximum c (negative numbers)');
};

subtest 'floating point numbers' => sub {
  my $values = [
    { a => 1.5, b => 2.7, c => 0.1 },
    { a => 3.14159, b => 2.71828, c => 1.41421 },
    { a => 0.001, b => 999.999, c => 42.0 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 0.001, 'minimum a (floating point)');
  is($minb, 2.7, 'minimum b (floating point)');
  is($minc, 0.1, 'minimum c (floating point)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 3.14159, 'maximum a (floating point)');
  is($maxb, 999.999, 'maximum b (floating point)');
  is($maxc, 42.0, 'maximum c (floating point)');
};

subtest 'mixed positive and negative' => sub {
  my $values = [
    { a => -5, b => 10, c => 0 },
    { a => 3, b => -8, c => -15 },
    { a => -2, b => 0, c => 7 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, -5, 'minimum a (mixed signs)');
  is($minb, -8, 'minimum b (mixed signs)');
  is($minc, -15, 'minimum c (mixed signs)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 3, 'maximum a (mixed signs)');
  is($maxb, 10, 'maximum b (mixed signs)');
  is($maxc, 7, 'maximum c (mixed signs)');
};

subtest 'all undefined values' => sub {
  my $values = [
    { a => undef, b => undef, c => undef },
    { a => undef, b => undef, c => undef },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, undef, 'minimum a (all undefined)');
  is($minb, undef, 'minimum b (all undefined)');
  is($minc, undef, 'minimum c (all undefined)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, undef, 'maximum a (all undefined)');
  is($maxb, undef, 'maximum b (all undefined)');
  is($maxc, undef, 'maximum c (all undefined)');
};

subtest 'some keys missing entirely' => sub {
  my $values = [
    { a => 1, b => 2 },
    { a => 3, c => 4 },
    { b => 5, c => 6 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 1, 'minimum a (some keys missing)');
  is($minb, 2, 'minimum b (some keys missing)');
  is($minc, 4, 'minimum c (some keys missing)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 3, 'maximum a (some keys missing)');
  is($maxb, 5, 'maximum b (some keys missing)');
  is($maxc, 6, 'maximum c (some keys missing)');
};

subtest 'zero values' => sub {
  my $values = [
    { a => 0, b => 0, c => 0 },
    { a => 5, b => -3, c => 0 },
    { a => -2, b => 0, c => 7 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, -2, 'minimum a (including zero)');
  is($minb, -3, 'minimum b (including zero)');
  is($minc, 0, 'minimum c (including zero)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 5, 'maximum a (including zero)');
  is($maxb, 0, 'maximum b (including zero)');
  is($maxc, 7, 'maximum c (including zero)');
};

subtest 'large numbers' => sub {
  my $values = [
    { a => 1e6, b => 1e-6, c => 1e12 },
    { a => 2e6, b => 2e-6, c => 2e12 },
    { a => 0.5e6, b => 0.5e-6, c => 0.5e12 },
  ];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, 0.5e6, 'minimum a (large numbers)');
  is($minb, 0.5e-6, 'minimum b (large numbers)');
  is($minc, 0.5e12, 'minimum c (large numbers)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, 2e6, 'maximum a (large numbers)');
  is($maxb, 2e-6, 'maximum b (large numbers)');
  is($maxc, 2e12, 'maximum c (large numbers)');
};

subtest 'empty data array' => sub {
  my $values = [];

  my ($mina, $minb, $minc);
  minimum($values, a => $mina, b => $minb, c => $minc);
  is($mina, undef, 'minimum a (empty array)');
  is($minb, undef, 'minimum b (empty array)');
  is($minc, undef, 'minimum c (empty array)');

  my ($maxa, $maxb, $maxc);
  maximum($values, a => $maxa, b => $maxb, c => $maxc);
  is($maxa, undef, 'maximum a (empty array)');
  is($maxb, undef, 'maximum b (empty array)');
  is($maxc, undef, 'maximum c (empty array)');
};

subtest 'single key operations' => sub {
  my $values = [
    { a => 1, b => 2, c => 3 },
    { a => 4, b => 5, c => 6 },
    { a => 7, b => 8, c => 9 },
  ];

  my $mina;
  minimum($values, a => $mina);
  is($mina, 1, 'minimum single key a');

  my $maxa;
  maximum($values, a => $maxa);
  is($maxa, 7, 'maximum single key a');

  my $minb;
  minimum($values, b => $minb);
  is($minb, 2, 'minimum single key b');

  my $maxc;
  maximum($values, c => $maxc);
  is($maxc, 9, 'maximum single key c');
};

done_testing;
