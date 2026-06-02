#!/usr/bin/perl
use warnings;
use Test::More;

# Perl 5.32+ chained comparison: A op1 B op2 C is equivalent to
#   (A op1 B) && (B op2 C)
# with each operand evaluated EXACTLY once, short-circuiting on the
# first false link. Mixing tiers (`1 < 2 == 1`) does NOT chain:
# `==` is precedence-tier 13 (equality), `<` is tier 14 (relational),
# so `1 < 2 == 1` parses as `(1 < 2) == 1`.
#
# perla previously rejected `1 < 2 < 3` outright with "expected
# RPAREN, got OP '<'" because the parser was strict single-pass.
# Then it briefly chained left-associatively. Now it builds an
# N_CHAIN_CMP node when same-tier ops follow, and the codegen
# materialises the operands-once, short-circuit semantics.

# Relational tier — all same op
ok( (1 < 2 < 3),     "1 < 2 < 3 chained = true");
ok(!(3 < 2 < 5),     "3 < 2 < 5 chained = false (short-circuit on first link)");
ok( (1 < 2 <= 3),    "1 < 2 <= 3 — mixed-op same-tier chains");
ok(!(1 < 3 < 2),     "1 < 3 < 2 = false (second link fails)");
ok( (10 > 5 > 1),    "10 > 5 > 1 chained = true");
ok(!(10 > 5 > 7),    "10 > 5 > 7 = false (second link)");

# Equality tier
ok( (1 == 1 == 1),   "1 == 1 == 1 chained = true");
ok(!(1 == 1 == 2),   "1 == 1 == 2 = false (second link)");
ok( (1 == 1 != 2),   "1 == 1 != 2 chained = true");
ok(!(1 == 1 != 1),   "1 == 1 != 1 = false");

# Mixed tiers — do NOT chain
ok( (1 < 2 == 1),    "1 < 2 == 1 parses as (1<2) == 1 (tiers don't mix)");

# String comparisons
ok( ("a" lt "b" lt "c"),  "string lt chains");
ok(!("c" lt "b" lt "d"),  "string lt false short-circuits");

# Side effects evaluated once
my @log;
sub trace { my $v = shift; push @log, "tr:$v"; $v }
@log = ();
my $r = trace(1) < trace(2) < trace(3);
is(scalar(@log), 3, "each operand evaluated exactly once");
is($log[0], "tr:1", "first operand evaluated first");
is($log[1], "tr:2", "middle operand evaluated once (not duplicated)");
is($log[2], "tr:3", "third operand evaluated last");

done_testing;
