#!/usr/bin/perl
use warnings;
use Test::More;

# `$arr[i] //= V` / `$ref->[i] //= V` — compound defined-or assignment
# on array elements. The dispatch table in _gen_assign for //= forgot
# the N_ARRAY_ELEM / N_ARROW_ARRAY branches: targets fell through to
# the `is_simple_lvalue` path which emits `gen_expr(target) = ...`,
# and that isn't a C lvalue for an array element. Result: a runtime
# `Can't modify non-lvalue in //= assignment` die. Concrete victim:
# the lazy-memoization idiom `$cache[$i] //= compute($i)`.

# Plain array
{
    my @cache;
    $cache[0] //= 100;
    is($cache[0], 100, "//= on undef array element installs value");

    $cache[1] = undef;
    $cache[1] //= 200;
    is($cache[1], 200, "//= on explicit undef element installs");

    $cache[2] //= 300;
    $cache[2] //= 999;
    is($cache[2], 300, "//= on defined element keeps existing");

    $cache[3] = 0;
    $cache[3] //= 42;
    is($cache[3], 0, "//= keeps defined 0 (vs ||=)");
}

# Arrow form on array ref
{
    my $ar = [];
    $ar->[0] //= "hello";
    is($ar->[0], "hello", "//= on ar->[i] installs");
    $ar->[0] //= "world";
    is($ar->[0], "hello", "//= on ar->[i] keeps existing");
}

# Negative index
{
    my @a = (1, 2, 3);
    $a[-1] //= 99;
    is($a[-1], 3, "//= on neg-index keeps existing");
    $a[-1] = undef;
    $a[-1] //= 99;
    is($a[-1], 99, "//= on neg-index installs after undef");
}

# Sanity: hash compound //= still works (pre-existing path).
{
    my %h;
    $h{a} //= 1;
    $h{a} //= 2;
    is($h{a}, 1, "//= on hash elem keeps prior");
}

done_testing;
