#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Perl destroys lexicals at scope exit in reverse declaration order.
# perla was destroying in forward declaration order — both at bare-block
# exit and at sub return. (Perl has a degenerate quirk when a bare block
# *ends with a `my` declaration* as its final statement — the last decl
# is freed last; that unspecified-internals case is intentionally not
# modelled. Every block/sub below ends in a normal statement, which is
# the realistic case where perl uses plain reverse order.)
our @order;
package Tracer;
sub new  { bless { id => $_[1] }, $_[0] }
sub DESTROY { push @main::order, $_[0]{id}; }

package main;

# Bare block (ends in a statement).
@order = ();
{
    my $a = Tracer->new("a");
    my $b = Tracer->new("b");
    my $c = Tracer->new("c");
    my $tmp = 0;
    $tmp++;
}
is("@order", "c b a", 'bare-block lexicals destroyed in reverse order');

# Sub return (pure LIFO).
@order = ();
sub make { my $x = Tracer->new("x"); my $y = Tracer->new("y"); my $z = Tracer->new("z"); return 1; }
make();
is("@order", "z y x", 'sub-local lexicals destroyed LIFO at return');

# Explicit return.
@order = ();
sub early { my $p = Tracer->new("p"); my $q = Tracer->new("q"); return 1; }
early();
is("@order", "q p", 'explicit return destroys declared-so-far in reverse');

# Nested blocks: inner destroyed before outer continues.
@order = ();
{
    my $outer = Tracer->new("outer");
    {
        my $inner1 = Tracer->new("inner1");
        my $inner2 = Tracer->new("inner2");
        my $z = 0; $z++;
    }
    push @order, "-mid-";
}
is("@order", "inner2 inner1 -mid- outer", 'nested-block destruction ordering');

done_testing;
