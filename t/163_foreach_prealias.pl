#!/usr/bin/perl
use warnings; use strict;
use Test::More;
# `for $x (LIST)` (no `my`) over a PRE-declared `my $x` must alias $x to each
# list element. Inside a block, the my-decl is renamed (x -> x__blkN) but the
# foreach loop variable is a raw token the rename pass missed — so the loop
# wrote the un-renamed C var while the body read the renamed one, and the body
# never saw the loop value (`for $x (10,2.5){ $x*2 }` gave 10,10 not 20,5).

{
    my $x = 5;
    my @r;
    for $x (10, 2.5) { push @r, $x * 2; }
    is("@r", "20 5", 'for $x over pre-declared my $x (in block) aliases correctly');
}

# nested foreach over two pre-declared block vars
{
    my $a = 0; my $b = 0; my @r;
    for $a (1, 2) { for $b (10, 20) { push @r, "$a:$b"; } }
    is("@r", "1:10 1:20 2:10 2:20", 'nested for $a/$b over pre-declared vars');
}

# the loop var holds non-int list values, not truncated
{
    my $v = 0; my @r;
    for $v ("a", "bb", "ccc") { push @r, length($v); }
    is("@r", "1 2 3", 'for $v aliases string elements, not the declared 0');
}

# a normal `for my $x` (fresh decl, no outer collision) still works
{
    my @r;
    for my $x (10, 2.5) { push @r, $x * 2; }
    is("@r", "20 5", 'normal for my $x unaffected');
}

# file-scope for $x (no block) still works
our $fs; for $fs (3, 4) {}  # just exercise; value semantics covered above
ok(1, 'file-scope for $x compiles/runs');

# `for my $x` declares a FRESH loop var; it must shadow an outer same-named
# `my $x` in the BODY but the LIST is still evaluated in the outer scope.
{
    my $x = 99; my @r;
    for my $x (10, 2.5) { push @r, $x * 2; }
    is("@r", "20 5", 'for my $x body uses fresh loop var, not outer');
    is($x, 99, 'outer $x unchanged after for my $x');
}
{
    my $x = 3; my @r;
    for my $x ($x, $x + 10) { push @r, $x; }   # list sees outer $x=3
    is("@r", "3 13", 'for my $x list is evaluated in outer scope');
    is($x, 3, 'outer $x still 3 after the loop');
}

done_testing;
