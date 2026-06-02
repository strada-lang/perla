#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Hexadecimal floating-point literals (Perl/C99 0x1.8p3 form): a hex
# mantissa with an optional fraction and a mandatory 'p'/'P' binary
# exponent. perla's lexer used to stop at the '.'/'p', emit just the
# integer part, and let the remainder corrupt the following tokens.

is(0x1p4,        16,   "0x1p4 = 1 * 2^4");
is(0x1.8p3,      12,   "0x1.8p3 = 1.5 * 2^3");
is(0x1.0p10,     1024, "0x1.0p10 = 1024");
is(0xAp-1,       5,    "0xAp-1 = 10 / 2");
is(0x1p0,        1,    "0x1p0 = 1");
is(0x1.4p2,      5,    "0x1.4p2 = 1.25 * 4");
is(0xFFp0,       255,  "0xFFp0 = 255");
cmp_ok(abs(0x1.99999999999ap-4 - 0.1), '<', 1e-12, "0x1.9..p-4 ≈ 0.1");
is(0x0.8p1,      1,    "0x0.8p1 = 0.5 * 2");
is(uc(sprintf("%X", 0x10)) . "", "10", "plain hex int unaffected");

# negative + capital P
is(-0x1p4,       -16,  "negation applies");
is(0x1P4,        16,   "capital P exponent");

# hex floats interoperate in arithmetic
is(0x1p4 + 0x1p2, 20,  "hex floats add");

# A hex/oct/bin integer followed by `.digit` (no 'p') is concat, not a
# float — these ints have no fractional form, so `0x10.8` is `16 . 8`.
is(0x10.8,    "168",    "0x10.8 is hex-int 16 concat 8");
is(0xff.0xff, "255255", "0xff.0xff concatenates two hex ints");
is(0x10 . 8,  "168",    "explicit 0x10 . 8 concat (regression)");
is(0b1010.5,  "105",    "0b1010.5 is binary-int 10 concat 5");
# decimal floats and leading-dot floats are unaffected
is(16.8,      16.8,     "decimal 16.8 is still a float");
is(.5 + .25,  0.75,     "leading-dot floats still parse");
is(5 . 3,     "53",     "number . number concat");

done_testing;
