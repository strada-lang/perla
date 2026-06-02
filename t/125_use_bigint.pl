#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `use bigint` — arbitrary-precision integer arithmetic for + - * ** and
# numeric comparison, plus exact big integer literals. (Division/modulo on
# values beyond int64 are not yet arbitrary-precision.)
use bigint;

is(2 ** 100, "1267650600228229401496703205376", '2 ** 100');
is(3 ** 50,  "717897987691852588770249",          '3 ** 50');

# factorial via compound *= (desugared to bignum)
my $f = 1;
$f *= $_ for 1 .. 30;
is($f, "265252859812191058636308480000000", '30! via *=');

# big literals + arithmetic
is(99999999999999999999 + 1, "100000000000000000000", 'big literal + 1');
is(1 - 10000000000000000000000, "-9999999999999999999999", 'subtraction goes negative');
is(12345678901234567890 * 98765432109876543210,
   "1219326311370217952237463801111263526900", 'big * big');
is((-5) ** 3, "-125", 'negative base odd power');

# comparisons
ok(2 ** 100 > 2 ** 99,                 'bignum > comparison');
ok(2 ** 64 == 18446744073709551616,    'bignum == comparison');
is(2 ** 100 <=> 2 ** 99, 1,            'bignum <=> ');

# small values still behave as plain integers (fast path)
is(2 + 2, 4, 'small add');
is(10 * 5, 50, 'small mul');
my @a = (10, 20, 30);
is($a[1 + 1], 30, 'small int still usable as array index');

# integer division / modulo (floor division; modulo takes the divisor's sign)
is(100000000000000000000 / 7, "14285714285714285714", 'big floor division');
is(100000000000000000000 % 7, "2",                     'big modulo');
is(-7 / 3, "-3", 'floor division rounds toward -inf');
is(-7 % 3, "2",  'modulo follows divisor sign');
is(7 % -3, "-2", 'modulo follows divisor sign (neg divisor)');

done_testing;
