#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `%*vd` — the vector flag with a custom join separator taken from an
# argument. The separator-marker `*` was consumed as the separator arg but
# left in the per-byte spec, making it `%*d`, which then read a bogus width
# argument off the stack and printed garbage.

is(sprintf("%*vd", "_", "1.2.3"), "49_46_50_46_51", "%*vd custom '_' separator");
is(sprintf("%*v02x", ":", "1.2.255"), "31:2e:32:2e:32:35:35", "%*v02x hex with ':' sep");
is(sprintf("%*vd", "-", sprintf("%c%c%c", 1, 2, 3)), "1-2-3", "%*vd over a built v-string");
is(sprintf("%*vd", "", "AB"), "6566", "%*vd with empty separator");

# default '.' separator and per-byte width still work (regression)
is(sprintf("%vd", "1.22.333"), "49.46.50.50.46.51.51.51", "%vd default '.' separator");
is(sprintf("%v03d", "1.2.3"), "049.046.050.046.051", "%v03d per-byte zero-pad width");
is(sprintf("%vd", chr(1) . chr(22) . chr(333)), "1.22.333", "%vd of a utf8 codepoint string");

# %*vd of a multi-char separator
is(sprintf("%*vd", "::", "AZ"), "65::90", "%*vd multi-char separator");

done_testing;
