#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Unsigned-64-bit (UV) integers: literals in (INT64_MAX, UINT64_MAX]
# and bitwise-complement results are held exactly as integers, not
# promoted to a lossy double. (Phase 1: representation, stringify,
# numeric-complement, comparison, length. Arithmetic on UV operands is
# a separate phase.)
is(18446744073709551615, 18446744073709551615, 'UV_MAX literal round-trips');
is(9223372036854775808, 9223372036854775808, '2**63 literal');
is(12345678901234567890, 12345678901234567890, 'arbitrary 20-digit literal');

is(~0, 18446744073709551615, '~0 is UV_MAX');
is(~5, 18446744073709551610, '~5 flips all bits unsigned');
is(~0xFF, 18446744073709551360, '~0xFF unsigned');

my $u = 18446744073709551615;
is("$u", "18446744073709551615", 'UV interpolates exactly');
is(length($u), 20, 'length of UV is its digit count');
ok($u > 9223372036854775807, 'UV compares greater than INT64_MAX');
ok($u == 18446744073709551615, 'UV numeric equality');
ok(~0 == $u, '~0 equals the UV_MAX literal');

is(sprintf("%u", ~0), "18446744073709551615", 'sprintf %u of UV');
is(sprintf("%x", ~0), "ffffffffffffffff", 'sprintf %x of UV');
is(sprintf("%d", ~0), "-1", 'sprintf %d of UV wraps to signed');

# Bitwise on UV.
is(~0 & 0xFF, 255, 'UV & mask');
ok(~0 ? 1 : 0, 'UV is true');

# Normal ints unaffected.
is(100, 100, 'small int');
is(-5, -5, 'negative int');
is(9223372036854775807, 9223372036854775807, 'INT64_MAX stays signed');

done_testing;
