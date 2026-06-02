#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Hash read-modify-write (`$h{$k}++`, `$h{$k} += N`, `$h{$k} .= S`, `||=`,
# `//=`) compiles to a single-probe lvalue lookup (strada_hv_fetch_lvalue*)
# instead of a fetch-then-store pair. These assertions lock the observable
# semantics that optimization must preserve: postfix returns the OLD value,
# an autoviv'd undef numifies to 0 in the result, decrement walks negative,
# compound ops mutate in place, and tied hashes still route through
# STORE/FETCH (the lvalue helper returns NULL for tied → fetch/store fallback).

# --- postfix ++ / -- return the OLD value, numifying undef to 0 ---
my %h;
my $r = $h{"a"}++;                 # autoviv: old is undef -> 0
is($r, 0, 'postfix ++ on fresh key returns 0 (undef numified)');
is($h{"a"}, 1, '... and stores 1');
$r = $h{"a"}++;
is($r, 1, 'postfix ++ returns prior value');
is($h{"a"}, 2, '... incremented in place');

my $k = "b";                       # variable key (the single-probe fast path)
$h{$k}++; $h{$k}++; $h{$k}--;
is($h{"b"}, 1, 'var-key ++/-- net to 1');

my %c = ("x" => 5);
my $old = $c{"x"}--;
is($old, 5, 'postfix -- returns old value');
is($c{"x"}, 4, '... decremented');

my %neg;
$neg{"d"}--;                       # 0 -> -1
is($neg{"d"}, -1, 'postfix -- on fresh key walks negative');

# --- compound assignment in place ---
my %s;
$s{"k"} = "p"; $s{"k"} .= "q"; $s{"k"} .= "r";
my $suf = "Z"; $s{"k"} .= $suf;
is($s{"k"}, "pqrZ", '.= chains in place (literal and var RHS)');

my %n;
$n{"v"} += 5;                      # autoviv 0 + 5
my $inc = 10; $n{"v"} += $inc;
is($n{"v"}, 15, '+= with literal then var RHS');

my %d;
$d{"u"} ||= 7;  $d{"u"} ||= 99;    # only first takes
$d{"w"} //= "set"; $d{"w"} //= "no";
is($d{"u"}, 7, '||= sets once');
is($d{"w"}, "set", '//= sets once');

# literal-key compound (distinct codegen branch from the var-key path)
my %lit;
$lit{"count"}++; $lit{"count"} += 3;
is($lit{"count"}, 4, 'literal-key ++ then += in place');

# --- float += keeps NV semantics ---
my %f;
$f{"pi"} += 3.14; $f{"pi"} += 0.001;
ok(abs($f{"pi"} - 3.141) < 1e-9, 'float += accumulates as NV');

# --- tied hash: lvalue helper must fall back so STORE/FETCH still fire ---
{
    package Counter;
    sub TIEHASH { bless { v => {}, stores => 0 }, shift }
    sub FETCH   { return $_[0]{v}{$_[1]} }
    sub STORE   { $_[0]{stores}++; $_[0]{v}{$_[1]} = $_[2] }
}
my %t;
tie %t, 'Counter';
$t{"z"} = 10;                      # 1 store
$t{"z"}++;                         # FETCH 10 -> STORE 11  (2nd store)
$t{"z"} += 4;                      # FETCH 11 -> STORE 15  (3rd store)
is($t{"z"}, 15, 'tied hash RMW routes through FETCH/STORE');
is((tied %t)->{stores}, 3, 'tied STORE fired on every RMW (no lvalue bypass)');

done_testing;
