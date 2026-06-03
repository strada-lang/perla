#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# In string interpolation, a variable whose leading element is a block/
# symbolic deref with a subscript — `${EXPR}[i]`, `${$ref}{k}`, `$$ref[i]` —
# must continue consuming the rest of the subscript/arrow chain. perla used to
# stop after the FIRST subscript, leaving e.g. `->{b}->[1]` as literal text:
#   "${$c->{a}}[0]->{b}->[1]"  printed  "HASH(0x..)->{b}->[1]"  not the value.

my $c    = { a => [ { b => [10, 20, 30] } ] };
my $aref = [ { b => [10, 20, 30] }, "second" ];
my $h    = { k => [7, 8, 9] };

# complex inner expr + arrow chain
is("${$c->{a}}[0]->{b}->[1]", 20, 'block-deref complex inner + arrow chain');
# simple block-deref + arrow chain
is("${$aref}[0]->{b}->[1]", 20, 'block-deref simple + arrow chain');
# brace-omitted chain (no explicit arrows)
is("${$aref}[0]{b}[1]", 20, 'block-deref + brace-omitted chain');
# $$ref deref + chain
is("$$aref[0]->{b}->[1]", 20, 'double-sigil deref + arrow chain');
is("$$aref[0]{b}[2]", 30, 'double-sigil deref + brace-omitted chain');
# hash-first block deref + chain
is("${$h}{k}[0]", 7, 'block-deref hash-first + chain');

# single subscript (no chain) still works — exercises the light Z: path
is("${$aref}[1]", "second", 'block-deref single subscript, no chain');
is("$$aref[1]", "second", 'double-sigil single subscript, no chain');

# chain must STOP at non-subscript text / method-arrow (no methods in interp)
is("x${$h}{k}[2]y", "x9y", 'chain stops at surrounding literal text');
is("$$aref[1]->x", "second->x", 'arrow-to-method left literal in interpolation');

done_testing;
