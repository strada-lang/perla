#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `local *name = sub {...}` (or = \&other) temporarily overrides a sub for
# the dynamic scope — the classic scoped-mock idiom. perla used
# perla_glob_get (NULL when the name had no prior `sub`), so the localized
# CODE slot was never installed and a later bareword call died "Undefined
# subroutine". Now it uses glob_get_or_create.

# override an existing sub, then verify restore after the block
sub greet { "real" }
{
    local *greet = sub { "mock" };
    is(greet(), "mock", "local *greet = sub overrides");
}
is(greet(), "real", "original restored after scope");

# override a name that was NEVER defined as a sub
{
    local *fresh = sub { "installed" };
    is(fresh(), "installed", "local *fresh = sub installs a brand-new sub");
}

# local *name = \&other (glob aliasing of an existing sub)
sub source { "from-source" }
{
    local *alias = \&source;
    is(alias(), "from-source", "local *alias = \\&source");
}

# arguments pass through the override
sub adder { $_[0] + $_[1] }
{
    local *adder = sub { $_[0] * $_[1] };
    is(adder(3, 4), 12, "override receives \@_");
}
is(adder(3, 4), 7, "original adder restored");

# regression: plain (non-local) glob assign + method override still work
*perm = sub { "permanent" };
is(perm(), "permanent", "plain *glob = sub still works");

package Obj; sub new { bless {}, shift } sub m { "real-method" }
package main;
my $o = Obj->new;
{
    local *Obj::m = sub { "mock-method" };
    is($o->m(), "mock-method", "local *Pkg::method override");
}
is($o->m(), "real-method", "method restored after scope");

done_testing;
