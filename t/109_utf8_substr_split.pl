#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use Test::More;

# For a UTF-8 (char-oriented) string, substr must operate on CHARACTER
# offsets and its result must stay char-oriented (length counts chars),
# and `split //` must split on character boundaries — not bytes.
# (perla's substr dropped the SVf_UTF8 flag on its result, so
# length(substr(...)) counted bytes; `split //` byte-split.)
my $s = "h\x{e9}llo";          # h é l l o  — 5 chars
is(length($s), 5, 'length counts chars');

is(length(substr($s, 0, 2)), 2, 'substr result length is in chars');
is(substr($s, 1, 1), "\x{e9}", 'substr extracts the right char');
is(length(substr($s, 1)), 4, '2-arg substr length in chars');
is(substr($s, -2), "lo", 'negative-offset substr');
is(length(substr($s, 2, -1)), 2, 'negative-length substr');

my @c = split //, $s;
is(scalar(@c), 5, 'split // yields one element per char');
is($c[1], "\x{e9}", 'split // keeps the multibyte char intact');
is(length($c[1]), 1, 'each split // piece is one char');
is(join("", @c), $s, 'split // round-trips');

# A multibyte char beyond Latin-1.
my $u = "a\x{1F600}b";          # a 😀 b — 3 chars
is(length($u), 3, 'astral char counts as 1');
my @uc = split //, $u;
is(scalar(@uc), 3, 'split // on astral char');
is(length($uc[1]), 1, 'astral split piece is 1 char');
is(substr($u, 1, 1), "\x{1F600}", 'substr extracts astral char');

# Plain ASCII unaffected.
is(join(",", split //, "abc"), "a,b,c", 'ascii split // unaffected');
is(substr("abcdef", 2, 2), "cd", 'ascii substr unaffected');

done_testing;
