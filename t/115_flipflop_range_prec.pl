#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# The range/flip-flop operator `..` / `...` lives at Perl precedence-3 (just
# below `?:`, above `||`/`&&`/comparison/`=~`). It used to be parsed far too
# tight (operands via the additive tier), so any `..` whose operand was a
# comparison, match, or logical expression mis-parsed — the scalar flip-flop
# silently collapsed to just its left operand.

# Scalar flip-flop with comparison operands.
my @o;
for my $n (1 .. 10) { push @o, $n if $n == 3 .. $n == 6; }
is("@o", "3 4 5 6", 'numeric flip-flop ($n==3 .. $n==6)');

# Scalar flip-flop with regex-match operands (statement modifier).
my @lines = ("a", "BEGIN", "x", "y", "END", "b", "BEGIN", "z", "END", "c");
my @r;
for (@lines) { push @r, $_ if /BEGIN/ .. /END/; }
is("@r", "BEGIN x y END BEGIN z END", 'regex flip-flop (/BEGIN/ .. /END/)');

# Three-dot flip-flop.
my @r3;
for (@lines) { push @r3, $_ if /BEGIN/ ... /END/; }
is("@r3", "BEGIN x y END BEGIN z END", 'three-dot flip-flop');

# Flip-flop inside an explicit if-block (not just statement modifier).
my @b;
for my $n (1 .. 8) { if ($n == 2 .. $n == 5) { push @b, $n; } }
is("@b", "2 3 4 5", 'flip-flop in if-block');

# Ordinary list ranges still work (regression).
is("@{[ 1 .. 5 ]}", "1 2 3 4 5", 'numeric list range');
is("@{[ 'a' .. 'e' ]}", "a b c d e", 'alpha list range');
my @data = (10, 20, 30, 40, 50);
is("@data[1 .. 3]", "20 30 40", 'array slice with range');

# Range with logical/comparison operands in list context picks the values.
my @c = ((1 + 1) .. (2 + 4));
is("@c", "2 3 4 5 6", 'range with additive operands');

# `..` is looser than `|`: `(1 | 2) .. 4` == `3 .. 4`.
my @d = (1 | 2) .. 4;
is("@d", "3 4", 'range looser than bitwise-or');

done_testing;
