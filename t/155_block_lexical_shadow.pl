#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# A `my $x` inside a nested bare block that SHADOWS an outer in-scope lexical
# (sub param or sub-local) must NOT clobber the outer var. perla reuses the C
# slot for the shadow; without save/restore the block permanently overwrote
# the outer value — `sub f{ my($x)=@_; { my $x={%$x}; $x->{c}=3 } [keys %$x] }`
# returned [a b c] instead of [a b]. The self-reference `{%$x}` in the shadow
# init must read the OUTER value (the new $x isn't in scope until after the
# statement), and the outer must survive unchanged after the block.

# --- scalar shadow of a sub-local ---
sub f { my $x = "OUTER"; { my $x = "INNER"; } return $x; }
is(f(), "OUTER", "block scalar shadow of sub-local leaves outer intact");

# --- scalar shadow of a sub param ---
sub g { my ($x) = @_; { my $x = "INNER"; } return $x; }
is(g("PARAM"), "PARAM", "block scalar shadow of param leaves outer intact");

# --- shadow init that references the outer same-named var ---
sub h { my ($x) = @_; { my $x = $x . "!"; } return $x; }
is(h("PARAM"), "PARAM", "self-referencing shadow init reads outer, leaves it intact");

# --- hashref copy-from-outer while shadowing (the moose2 _expand_groups case) ---
sub same { my ($x) = @_; { my $x = { %$x }; $x->{c} = 3; } return [sort keys %$x]; }
is_deeply(same({ a => 1, b => 2 }), ['a', 'b'], "shadow `my \$x={%\$x}` copies, outer keeps [a b]");

# --- different-name control: must also be clean ---
sub diff { my ($x) = @_; { my $z = { %$x }; $z->{c} = 3; } return [sort keys %$x]; }
is_deeply(diff({ a => 1, b => 2 }), ['a', 'b'], "different-name copy leaves outer intact");

# --- the shadow's own value must be the modified copy inside the block ---
sub inner { my ($x) = @_; my $seen; { my $x = { %$x }; $x->{c} = 3; $seen = [sort keys %$x]; } return $seen; }
is_deeply(inner({ a => 1, b => 2 }), ['a', 'b', 'c'], "shadow sees its own modified copy [a b c]");

# --- nested shadowing: two levels deep ---
sub nest {
    my ($x) = @_;
    {
        my $x = $x . "1";
        {
            my $x = $x . "2";
            is($x, "P12", "innermost shadow sees middle value");
        }
        is($x, "P1", "middle shadow restored after inner block");
    }
    return $x;
}
is(nest("P"), "P", "outermost param restored after nested blocks");

# --- array shadow ---
sub arr { my @x = (1, 2, 3); { my @x = (9); } return scalar(@x); }
is(arr(), 3, "block array shadow leaves outer array intact");

done_testing;
