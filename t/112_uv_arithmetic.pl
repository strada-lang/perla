#!/usr/bin/perl
use warnings;
no warnings qw(portable numeric);  # focus on values, not warning-emission parity
use strict;
use Test::More;

# UV arithmetic phase 2: +, -, *, % on unsigned-64 operands stay exact;
# hex/oct of full-width values yield UV; int/abs preserve a UV.
my $u = 18446744073709551615;   # UV_MAX

is($u - 1, 18446744073709551614, 'UV - 1');
is($u - 5, 18446744073709551610, 'UV - 5');
is(~0 - 5, 18446744073709551610, '~0 - 5 (complement then subtract)');
is(18446744073709551610 + 5, $u, 'literal UV + small');
is($u * 1, $u, 'UV * 1');
is($u - $u, 0, 'UV - UV = 0');
is($u % 10, 5, 'UV % 10 (unsigned modulo)');
is($u % 3, 0, 'UV % 3');
is(~0 % 7, 1, '~0 % 7');

is(hex("ffffffffffffffff"), $u, 'hex full-width = UV_MAX');
is(hex("FF"), 255, 'hex small unaffected');
is(oct("0x" . "f" x 16), $u, 'oct 0x full-width');
is(oct("0b" . "1" x 64), $u, 'oct 0b 64 ones = UV_MAX');
is(oct("777"), 511, 'oct small unaffected');

is(int($u), $u, 'int(UV) preserves the value');
is(abs($u), $u, 'abs(UV) preserves the value');

# Overflow past UINT64_MAX falls back to float (matches perl).
ok($u + 1 > 1e19, 'UV_MAX + 1 overflows to a large float');

# Normal arithmetic unaffected.
is(2 + 3, 5, 'small add');
is(10 % 3, 1, 'small mod');
is(7 - 9, -2, 'negative result');
is(int(3.7), 3, 'int of float');
is(abs(-4), 4, 'abs of negative');

# IV+IV that overflows int64 into the UV range promotes to UV (not NV).
is(9223372036854775807 + 9223372036854775807, 18446744073709551614, 'INT64_MAX + INT64_MAX -> UV');
is(4000000000 * 4000000000, 16000000000000000000, 'positive product overflowing int64 -> UV');
is(9223372036854775807 + 1, 9223372036854775808, 'INT64_MAX + 1 -> exact (UV)');
is(9000000000000000000 - -9000000000000000000, 18000000000000000000, 'subtraction overflow -> UV');
{
    my $a = 9223372036854775807;
    my $b = 9223372036854775807;
    is($a + $b, 18446744073709551614, 'variables holding INT64_MAX add to UV');
}
# A result that overflows the tagged range but fits int64 stays an exact int.
is(5000000000000000000, 5000000000000000000, '5e18 literal exact');
# Past UINT64_MAX falls back to float (matches perl).
ok(10000000000 * 10000000000 > 1e19, 'product past UV_MAX is a large float');

# A numeric STRING whose value is in the UV range numifies to a UV in
# arithmetic (rather than a lossy double).
is("18446744073709551615" + 0, 18446744073709551615, 'UV-range string + 0');
is("18446744073709551615" - 1, 18446744073709551614, 'UV-range string - 1');
is("18446744073709551615" % 10, 5, 'UV-range string % 10');
{
    my $s = "18446744073709551610";
    is($s + 5, 18446744073709551615, 'UV-range string var + 5');
    is($s * 1, 18446744073709551610, 'UV-range string var * 1');
}
# Strings NOT in the UV range are unaffected.
is("123" + 0, 123, 'small numeric string');
is("-5" + 0, -5, 'negative numeric string');
is("3.14" + 0, 3.14, 'float numeric string');
is("abc" + 0, 0, 'non-numeric string');

done_testing;
