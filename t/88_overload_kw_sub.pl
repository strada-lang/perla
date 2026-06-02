#!/usr/bin/perl
use warnings;
use Test::More;

# `\&NAME` where NAME is a perl-keyword operator (eq, ne, lt, gt, le, ge,
# cmp, and, or, not, xor, x) must yield a CODE ref to the sub, not a
# SCALAR ref to undef. Without this, `use overload '==' => \&eq` silently
# registered nothing — the sub `eq` was tokenized as an OP and the parser
# fell through `\&OP` to the undef-fallback.
{
    sub eq  { "eq sub" }
    sub ne  { "ne sub" }
    sub cmp { "cmp sub" }
    sub and { "and sub" }

    my $r_eq  = \&eq;
    my $r_ne  = \&ne;
    my $r_cmp = \&cmp;
    my $r_and = \&and;

    is(ref($r_eq),  "CODE", "\\&eq is a CODE ref");
    is(ref($r_ne),  "CODE", "\\&ne is a CODE ref");
    is(ref($r_cmp), "CODE", "\\&cmp is a CODE ref");
    is(ref($r_and), "CODE", "\\&and is a CODE ref");
    is($r_eq->(),  "eq sub",  "\\&eq dispatches to sub eq");
    is($r_ne->(),  "ne sub",  "\\&ne dispatches to sub ne");
    is($r_cmp->(), "cmp sub", "\\&cmp dispatches to sub cmp");
    is($r_and->(), "and sub", "\\&and dispatches to sub and");
}

# The overload case that surfaced the bug — `use overload '==' => \&eq`
# with the sub defined later in the package.
{
    package Vec;
    use overload
        '==' => \&eq,
        '""' => \&stringify;
    sub new { my $c = shift; bless [@_], $c }
    sub eq { my ($s, $o) = @_; $s->[0] == $o->[0] && $s->[1] == $o->[1] }
    sub stringify { my $s = shift; "($s->[0],$s->[1])" }

    package main;
    my $v1 = Vec->new(1, 2);
    my $v2 = Vec->new(1, 2);
    my $v3 = Vec->new(1, 3);
    ok(  $v1 == $v2,  "overload == dispatches via \\&eq (equal)");
    ok(!($v1 == $v3), "overload == dispatches via \\&eq (unequal)");
    is("$v1", "(1,2)", "overload \"\" still works alongside");
}

done_testing;
