#!/usr/bin/perl

# Daniel "Trizen" Șuteu
# Date: 27 August 2022
# https://github.com/trizen

# Generate all the Lucas-Carmichael numbers with n prime factors in a given range [a,b]. (not in sorted order)

# See also:
#   https://en.wikipedia.org/wiki/Almost_prime
#   https://trizenx.blogspot.com/2020/08/pseudoprimes-construction-methods-and.html

# PARI/GP program (up to n):
#   upto(n, k) = my(A=vecprod(primes(k+1))\2, B=n); (f(m, l, p, k, u=0, v=0) = my(list=List()); if(k==1, forprime(p=u, v, my(t=m*p); if((t+1)%l == 0 && (t+1)%(p+1) == 0, listput(list, t))), forprime(q = p, sqrtnint(B\m, k), my(t = m*q); my(L=lcm(l, q+1)); if(gcd(L, t) == 1, my(u=ceil(A/t), v=B\t); if(u <= v, my(r=nextprime(q+1)); if(k==2 && r>u, u=r); list=concat(list, f(t, L, r, k-1, u, v)))))); list); vecsort(Vec(f(1, 1, 3, k)));

# PARI/GP program (in range [A,B]):
#   lucas_carmichael(A, B, k) = A=max(A, vecprod(primes(k+1))\2); (f(m, l, p, k, u=0, v=0) = my(list=List()); if(k==1, forprime(p=u, v, my(t=m*p); if((t+1)%l == 0 && (t+1)%(p+1) == 0, listput(list, t))), forprime(q = p, sqrtnint(B\m, k), my(t = m*q); my(L=lcm(l, q+1)); if(gcd(L, t) == 1, my(u=ceil(A/t), v=B\t); if(u <= v, my(r=nextprime(q+1)); if(k==2 && r>u, u=r); list=concat(list, f(t, L, r, k-1, u, v)))))); list); vecsort(Vec(f(1, 1, 3, k)));

use 5.020;
use ntheory qw(:all);
use experimental qw(signatures);

sub divceil ($x,$y) {   # ceil(x/y)
    my $q = divint($x, $y);
    ($q*$y == $x) ? $q : ($q+1);
}

sub lucas_carmichael_numbers_in_range ($A, $B, $k, $callback) {

    $A = vecmax($A, pn_primorial($k));

    sub ($m, $lambda, $p, $k, $u = undef, $v = undef) {

        if ($k == 1) {

            forprimes {
                my $t = $m*$_;
                if (($t+1)%$lambda == 0 and ($t+1)%($_+1) == 0) {
                    $callback->($t);
                }
            } $u, $v;

            return;
        }

        my $s = rootint(divint($B, $m), $k);

        for(my $r; $p <= $s; $p = $r) {

            $r = next_prime($p);

            my $L = lcm($lambda, $p+1);
            gcd($L, $m) == 1 or next;

            # gcd($m*$p, divisor_sum($m*$p)) == 1 or die "$m*$p: not Lucas-cyclic";

            my $t = $m*$p;
            my $u = divceil($A, $t);
            my $v = divint($B, $t);

            if ($u <= $v) {
                __SUB__->($t, $L, $r, $k - 1, (($k==2 && $r>$u) ? $r : $u), $v);
            }
        }
    }->(1, 1, 3, $k);
}

# Generate all the Lucas-Carmichael numbers with 5 prime factors in the range [100, 10^8]

my $k    = 5;
my $from = 100;
my $upto = 1e8;

my @arr; lucas_carmichael_numbers_in_range($from, $upto, $k, sub ($n) { push @arr, $n });

say join(', ', sort { $a <=> $b } @arr);

__END__
588455, 1010735, 2276351, 2756159, 4107455, 4874639, 5669279, 6539819, 8421335, 13670855, 16184663, 16868159, 21408695, 23176439, 24685199, 25111295, 26636687, 30071327, 34347599, 34541639, 36149399, 36485015, 38999519, 39715319, 42624911, 43134959, 49412285, 49591919, 54408959, 54958799, 57872555, 57953951, 64456223, 66709019, 73019135, 77350559, 78402815, 82144799, 83618639, 86450399, 93277079, 96080039, 98803439
