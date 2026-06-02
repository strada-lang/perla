#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# A multi-element `use constant` is a LIST constant: Perl backs it with
# `@list`, so scalar context yields the element COUNT (not the comma
# operator's last element). perla was returning the last element.
use constant DAYS => ('Mon', 'Tue', 'Wed');
use constant PAIR => (10, 20);
use constant SINGLE => 42;
use constant ONELIST => (99);

my @d = DAYS;
is("@d", "Mon Tue Wed", 'list constant in list context');
is(scalar(DAYS), 3, 'list constant in scalar context = count');
my $s = DAYS;
is($s, 3, 'list constant scalar assignment = count');
is((DAYS)[1], "Tue", 'list constant element access');
is(join(",", DAYS, "x"), "Mon,Tue,Wed,x", 'list constant flattens in a bigger list');

is(scalar(PAIR), 2, 'two-element list constant scalar = count');

# Single-value constants keep value semantics.
is(SINGLE, 42, 'single constant value');
is(scalar(SINGLE), 42, 'single constant scalar = value');
is(ONELIST, 99, 'single-element-list constant = value');
is(scalar(ONELIST), 99, 'parenthesized single value = value, not count');

# Used in a loop / arithmetic.
my $total = 0; $total += length($_) for DAYS;
is($total, 9, 'iterate list constant');
is(0 + scalar(DAYS), 3, 'count usable in arithmetic');

done_testing;
