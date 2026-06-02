#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use Test::More;

# chop must remove the last CHARACTER, not the last byte, for UTF-8
# strings. (perla's strada_chop dropped a single byte, splitting a
# multibyte char.)
my $s = "caf\x{e9}";
my $removed = chop $s;
is($s, "caf", 'chop leaves the preceding chars intact');
is(length($s), 3, 'chop reduces char length by one');
is($removed, "\x{e9}", 'chop returns the removed character');
is(length($removed), 1, 'removed value is one char');

# Astral (4-byte) char.
my $a = "x\x{1F600}";
my $r = chop $a;
is($a, "x", 'chop removes a 4-byte char wholesale');
is($r, "\x{1F600}", 'chop returns the astral char');
is(length($r), 1, 'astral removed value is one char');

# Trailing ASCII char on an otherwise-UTF-8 string.
my $m = "\x{e9}abc";
chop $m;
is($m, "\x{e9}ab", 'chop ascii tail of utf8 string');
is(length($m), 3, 'length after chopping ascii tail');

# Plain ASCII unaffected.
my $ascii = "hello";
my $ar = chop $ascii;
is($ascii, "hell", 'ascii chop');
is($ar, "o", 'ascii chop return');

# chop on an array chops each element.
my @list = ("ab\x{e9}", "xy");
chop @list;
is($list[0], "ab", 'chop @array element 0');
is($list[1], "x",  'chop @array element 1');

done_testing;
