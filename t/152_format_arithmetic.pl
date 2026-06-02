#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# format value lines may be arithmetic expressions (computed report
# columns): `$price * $qty`, `$a % $b`, `int($n/3)`, `abs($a-$b)`. perla's
# value-line parser only handled bare vars / literals / "lit".$var concat,
# so arithmetic rendered as 0. A small numeric evaluator now handles it.
# Write to a named handle on a temp file and read it back.

my $tmp = "/tmp/perla_fmtarith_$$.txt";
sub slurp { open my $fh, "<", $tmp or return ""; local $/; my $c = <$fh>; close $fh; unlink $tmp; return $c; }

our ($price, $qty, $tax);
format OUTA =
@#####.## @##.## @###
$price * $qty, $price * $qty * $tax, int($qty * 2 + 1)
.
$price = 19.99; $qty = 3; $tax = 0.08;
open(OUTA, ">", $tmp) or die; write OUTA; close OUTA;
is(slurp(), "    59.97   4.80    7\n", "multiply, chained multiply, int() of arith");

our ($a, $b);
format OUTB =
@### @### @#### @### @####
$a + $b, $a - $b, $a * $b, $a % $b, abs($a - $b * 5)
.
$a = 10; $b = 3;
open(OUTB, ">", $tmp) or die; write OUTB; close OUTB;
is(slurp(), "  13    7    30    1     5\n", "+ - * % and abs()");

# precedence + parens + power
our $n;
format OUTC =
@##### @#### @####
$n * 2 + 1, ($n + 1) * 2, $n ** 2
.
$n = 5;
open(OUTC, ">", $tmp) or die; write OUTC; close OUTC;
is(slurp(), "    11    12    25\n", "precedence, parens, power");

# regression: bare var (string), literal, and concat still render as before
our ($name, $cnt);
format OUTD =
@<<<<<<< @## @<<<
$name, $cnt, "x-y"
.
$name = "a-b-c"; $cnt = 7;
open(OUTD, ">", $tmp) or die; write OUTD; close OUTD;
is(slurp(), "a-b-c      7 x-y\n", "string var with hyphens + literal unaffected");

done_testing;
