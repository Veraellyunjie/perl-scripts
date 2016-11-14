#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 14 November 2016
# Website: https://github.com/trizen

# An interesting function that computes the sum of
# divisors (excluding the trivial divisors 1 and n),
# each divisor raised to its p-adic valuation ν_d(n).

# For prime numbers, the value of `sigma_p_adic(p)` is 0.

# See also:
#   https://en.wikipedia.org/wiki/P-adic_order
#   https://en.wikipedia.org/wiki/Legendre%27s_formula

use 5.010;
use strict;
use warnings;

use ntheory qw(divisors forcomposites);

sub p_adic {
    my ($p, $n) = @_;

    my $s = 0;
    while ($n >= $p) {
        $s += int($n /= $p);
    }

    $s;
}

sub sigma_p_adic {
    my ($n) = @_;

    my @d = divisors($n);

    shift @d;    # remove the first divisor (which is: 1)
    pop @d;      # remove the last  divisor (which is: n)

    my $s = 0;
    foreach my $d (@d) {
        $s += $d**p_adic($d, $n);
    }

    return $s;
}

forcomposites {
    say $_, "\t", join ' ', sigma_p_adic($_);
} 30;

__END__
4       8
6       25
8       144
9       81
10      281
12      1367
14      2097
15      854
16      33856
18      72394
20      266965
21      20026
22      524409
24      4271689
25      15625
26      8388777
27      1595052
28      33622565
30      71978959
