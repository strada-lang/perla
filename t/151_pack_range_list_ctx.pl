#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# pack(TEMPLATE, LIST) evaluates its arguments in list context. A bare
# range `1..5` (or map/grep) passed to pack in a scalar-context call —
# e.g. `my $s = pack("C*", 1..5)` — was evaluated in scalar context, so
# the range became the flip-flop operator (a single value) and only one
# element got packed (length 1 instead of 5).

my $s = pack("C*", 1..5);
is(length($s), 5, "pack C* 1..5 stored — full length");
is_deeply([unpack("C*", $s)], [1, 2, 3, 4, 5], "pack C* 1..5 stored — all bytes");

my $n = pack("N*", 1..3);
is(length($n), 12, "pack N* 1..3 — 3 x 4 bytes");
is_deeply([unpack("N*", $n)], [1, 2, 3], "pack N* 1..3 values");

# map / grep arguments are also list context
is_deeply([unpack("C*", pack("C*", map { $_ * 10 } 1..3))], [10, 20, 30], "map arg");
is_deeply([unpack("C*", pack("C*", grep { $_ > 2 } 1..5))], [3, 4, 5], "grep arg");

# a descending range
my $d = pack("C*", reverse 1..4);
is_deeply([unpack("C*", $d)], [4, 3, 2, 1], "reverse range");

# regressions: explicit list, array var, inline all still work
is_deeply([unpack("C*", pack("C*", 1, 2, 3))], [1, 2, 3], "explicit list");
my @a = (1 .. 5);
is_deeply([unpack("C*", pack("C*", @a))], [1, 2, 3, 4, 5], "array var");
is_deeply([unpack("C*", pack("C*", 1 .. 5))], [1, 2, 3, 4, 5], "inline (was already ok)");

# mixed: a range followed by explicit values
my $m = pack("C*", 1 .. 3, 9, 8);
is_deeply([unpack("C*", $m)], [1, 2, 3, 9, 8], "range then explicit values");

done_testing;
