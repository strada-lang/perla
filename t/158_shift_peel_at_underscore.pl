#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# perla peels a leading `my $x = shift` into a direct parameter when it
# believes the rest of the body never observes @_. Two @_-observing shapes
# were missed, so the peel fired and later @_ reads saw the PRE-shift @_:
#   (1) `goto &EXPR` / `goto $coderef` (N_GOTO_SUB) — tail-calls with @_;
#   (2) @_ / $_[N] interpolated inside a double-quoted string.
# (1) is the Error::TypeTiny::throw shape (`splice(@_,1,0,undef); goto $next`)
# that made Type::Tiny AUTOLOAD receive a CODE invocant.

# --- @_ in interpolation after shift ---
sub t1 { my $c = shift; return "rest: @_"; }
is(t1("a", "b", "c"), "rest: b c", 'interpolated @_ after shift is post-shift');

# --- $_[N] in interpolation after shift ---
sub t2 { my $c = shift; return "first: $_[0]"; }
is(t2("a", "b", "c"), "first: b", 'interpolated $_[0] after shift is post-shift');

# --- goto $coderef passes the post-shift @_ ---
package Foo;
sub target { return "n=" . scalar(@_) . " [@_]"; }
sub entry { my $code = shift; goto $code; }
package main;
my $t = Foo->can('target');
is(Foo::entry($t, "x", "y"), "n=2 [x y]", 'goto $coderef passes post-shift @_');

# --- the Error::TypeTiny::throw shape: splice @_ then goto coderef ---
package Bar;
sub handler { my $self = shift; my $cb = shift; return "self=$self cb=" . (defined($cb) ? $cb : "undef") . " args=[@_]"; }
sub throw { my $next = $_[0]->can('handler'); splice(@_, 1, 0, "CB"); goto $next; }
package main;
is(Bar->throw("a", "b"), "self=Bar cb=CB args=[a b]", 'splice @_ then goto coderef preserves modified @_');

# --- plain (non-interpolated, non-goto) shift still peels correctly ---
sub plain { my $x = shift; my $y = shift; return $x + $y; }
is(plain(3, 4, 5), 7, 'plain shift-peel unaffected');

done_testing;
