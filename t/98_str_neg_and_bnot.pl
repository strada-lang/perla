#!/usr/bin/perl
use warnings;
use Test::More;

# Unary `-` on a non-numeric string follows perl's identifier-negation
# rule from perlop:
#   -"foo"   → "-foo"   (prepend a dash)
#   -"-foo"  → "+foo"   (flip leading dash to plus)
#   -"+foo"  → "-foo"   (flip leading plus to dash)
#   -"5xyz"  → numeric negation via the to_num path
# perla previously fell through to `strada_new_num(-strada_to_num(...))`
# which gave `0` for any non-numeric-looking string, so `-"foo"` was 0.

is(-"foo",   "-foo",  "-IDENT prepends a dash");
is(-"-foo",  "+foo",  "-(-IDENT) flips - to +");
is(-"+foo",  "-foo",  "-(+IDENT) flips + to -");
is(-"5",     -5,      "-numeric-string negates numerically");
is(-"5.5",   -5.5,    "-numeric-string with decimal still negates");

# Bitwise `~` on a non-negative int uses unsigned 64-bit semantics
# in perl: `~5` is `0xFFFFFFFFFFFFFFFA` = 18446744073709551610. perla
# previously used signed semantics (~5 = -6). Since u64 max doesn't
# fit i64, the result above INT64_MAX comes back as a decimal string
# (matching perl's stringification rather than scientific notation).
is(~5,   "18446744073709551610", "~5 = unsigned bitwise-not");
is(~0,   "18446744073709551615", "~0 = u64-max (all bits set)");
is(~-1,  0,                        "~-1 = 0 (signed path)");

done_testing;
