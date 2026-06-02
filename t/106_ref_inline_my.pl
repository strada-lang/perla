#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Taking a reference to a freshly-declared lexical: `\my @a` / `\my %h`
# must yield an ARRAY / HASH ref, not a SCALAR ref. (The expression-form
# `my` codegen initialised an uninitialised array/hash declaration to a
# scalar undef, so the ref came out SCALAR and was unusable.)
my $ar = \my @arr;
is(ref($ar), "ARRAY", '\my @a is an ARRAY ref');
push @$ar, 1, 2, 3;
is("@arr", "1 2 3", 'pushes through \my @a reach the array');
is(scalar(@$ar), 3, 'deref count via the ref');

my $hr = \my %hash;
is(ref($hr), "HASH", '\my %h is a HASH ref');
$hr->{x} = 10;
$hr->{y} = 20;
is($hash{x} + $hash{y}, 30, 'stores through \my %h reach the hash');
is(join(",", sort keys %$hr), "x,y", 'keys via the ref');

my $sr = \my $scalar;
is(ref($sr), "SCALAR", '\my $s is still a SCALAR ref');
$$sr = 42;
is($scalar, 42, 'store through \my $s');

# Inline in a larger expression.
my @refs = (\my @p, \my @q);
is(ref($refs[0]), "ARRAY", 'list of \my @ refs, elem 0');
is(ref($refs[1]), "ARRAY", 'list of \my @ refs, elem 1');
push @{$refs[0]}, "a";
push @{$refs[1]}, "b";
is("@p @q", "a b", 'each inline-my array is independent');

done_testing;
