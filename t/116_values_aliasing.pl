#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `for (values %h)` aliases the loop variable to each hash value slot, so
# modifying the loop var writes back into the hash (Perl aliasing). Both the
# block form and the statement-modifier form, on plain hashes and hashref
# derefs. `keys` is NOT aliased.

# Statement-modifier form.
my %h1 = (a => 1, b => 2, c => 3);
$_ *= 10 for values %h1;
is(join(",", map { "$_=$h1{$_}" } sort keys %h1), "a=10,b=20,c=30",
   'statement-modifier: $_ *= 10 for values %h');

# Block form with explicit my var.
my %h2 = (a => 1, b => 5);
for my $v (values %h2) { $v += 100; }
is(join(",", map { "$_=$h2{$_}" } sort keys %h2), "a=101,b=105",
   'block form: for my $v (values %h)');

# Block form with default $_.
my %h3 = (x => 2, y => 3);
for (values %h3) { $_ = $_ * $_; }
is(join(",", map { "$_=$h3{$_}" } sort keys %h3), "x=4,y=9",
   'block form default $_');

# Hashref deref.
my $r = { p => 5, q => 6 };
$_++ for values %$r;
is("$r->{p},$r->{q}", "6,7", 'values %$ref aliasing (statement modifier)');

my $r2 = { p => 5, q => 6 };
for (values %$r2) { $_ *= 2; }
is("$r2->{p},$r2->{q}", "10,12", 'values %$ref aliasing (block)');

# Read-only use of values is unchanged.
my %h4 = (a => 3, b => 1, c => 2);
is(join(",", sort { $a <=> $b } values %h4), "1,2,3", 'values still readable');

# keys is NOT aliased — modifying $_ does not change the hash keys.
my %h5 = (a => 1, b => 2);
for (keys %h5) { $_ = "Z"; }
is(join(",", sort keys %h5), "a,b", 'keys not aliased');

# Empty hash: no iterations, no crash.
my %h6;
my $n = 0;
$n++ for values %h6;
is($n, 0, 'empty hash values');

done_testing;
