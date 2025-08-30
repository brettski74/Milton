#!/usr/bin/perl

use lib '.';
use Test2::V0;
use Milton::Math::Util qw(meanSquaredError);

my $EPS = 0.00000001;

# Test basic functionality with simple linear function
subtest 'basic linear function' => sub {
    # Function: f(x) = 2x + 1
    my $linear_fn = sub { my $x = shift; return 2 * $x + 1; };  # Return predicted value
    
    # Test with single sample: [input, expected_output]
    my $mse = meanSquaredError($linear_fn, [5, 11]);
    # f(5) = 11, expected = 11, error = 11 - 11 = 0, MSE = 0² = 0
    is($mse, 0, 'single sample perfect fit');

    $mse = meanSquaredError($linear_fn, [5, 13]);
    is($mse, 4, 'single sample imperfect fit');
    
    # Test with multiple samples
    $mse = meanSquaredError($linear_fn, [1, 3], [2, 5], [4, 9], [7, 15]);
    # All samples are perfect fits, so MSE = 0
    is($mse, 0, 'multiple samples perfect fit');

    $mse = meanSquaredError($linear_fn, [1, 3.2], [2, 4.8], [4, 9.3], [7, 14.6]);
    is($mse, float(0.0825, tolerance => $EPS), 'imperfect fit MSE calculation');
};

# Test with multivariate function
subtest 'multivariate function' => sub {
    # Function: f(x) = x² + 2x + 1
    my $sum = sub { my ($x, $y) = @_; return $x + $y; };
    
    my $mse = meanSquaredError($sum, [1, 3, 4], [1, 2, 3], [2, 5, 7], [5, 7, 12]);
    is($mse, 0, 'multivariate function perfect fit');
    
    $mse = meanSquaredError($sum, [1, 3, 4.2], [1, 2, 3.5], [2, 5, 7.2], [5, 7, 11.9]);
    is($mse, float(0.085, tolerance => $EPS), 'imperfect multivariate fit MSE');
};

# Test error handling
subtest 'error handling' => sub {
    # Test with empty sample list
    my $fn = sub { return 1; };
    
    # No samples provided
    eval {
        my $mse = meanSquaredError($fn);
        fail('should have thrown error for empty samples');
    };

    like($@, qr/no samples/i, 'no samples causes error');

    # Test with undefined function
    eval {
        my $mse = meanSquaredError(undef, [1, 2], [2, 3], [3, 4]);
        fail('should have thrown error for undefined function');
    };
    like($@, qr/expected.*not.*code reference/i, 'undefined function causes error');
    
    # Test with non-function reference
    eval {
        my $mse = meanSquaredError("not a function", [1, 2], [2, 3], [3, 4]);
        fail('should have thrown error for non-function reference');
    };
    like($@, qr/expected.*not.*code reference/i, 'non-function reference causes error');
    
    # Test with malformed sample (not array reference)
    eval {
        my $fn = sub { return 1; };
        my $mse = meanSquaredError($fn, 1, 2, 3);
        fail('should have thrown error for non-array sample');
    };
    like($@, qr/sample 0.*not.*array reference/i, 'non-array sample causes error');

    # Test with malformed sample (not array reference)
    eval {
        my $fn = sub { my @sample = @_; return 1; };
        my $mse = meanSquaredError($fn, [ 1, 1 ], 2, 3);
        fail('should have thrown error for non-array sample');
    };
    like($@, qr/sample 1.*not.*array reference/i, 'non-array sample causes error');

    # Test with a malformed sample (single element array)
    eval {
        my $fn = sub { my @sample = @_; return 1; };
        my $mse = meanSquaredError($fn, [ 1 ]);
        fail('should have thrown error for single element sample');
    };
    like($@, qr/sample 0.*element/i, 'single element sample causes error');

    # Test with a malformed sample (single element array)
    eval {
        my $fn = sub { my @sample = @_; return 1; };
        my $mse = meanSquaredError($fn, [ 1, 2 ], [ 1 ]);
        fail('should have thrown error for single element sample');
    };
    like($@, qr/sample 1.*element/i, 'single element sample causes error');
};

done_testing(); 
