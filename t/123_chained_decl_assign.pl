#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Chained declaration-assignment: `my @A = my @B = LIST` and the `our`
# equivalent `our @A = our @B = LIST` (the Exporter idiom
# `our @EXPORT = our @EXPORT_OK = qw(...)`). Both targets must receive the
# full list, and each must be an INDEPENDENT copy (Perl semantics), not an
# alias to the same backbone.

# --- my, array ---
{
    my @A = my @B = (1, 2, 3);
    is_deeply(\@A, [1, 2, 3], 'my @A gets the list');
    is_deeply(\@B, [1, 2, 3], 'my @B gets the list');
    push @A, 4;
    is_deeply(\@B, [1, 2, 3], 'my @B unaffected by push @A (independent copy)');
}

# --- our, array (Exporter idiom) ---
our @EXPORT = our @EXPORT_OK = qw(try catch finally);
is_deeply(\@EXPORT,    [qw(try catch finally)], 'our @EXPORT gets the list');
is_deeply(\@EXPORT_OK, [qw(try catch finally)], 'our @EXPORT_OK gets the list');
push @EXPORT, 'extra';
is_deeply(\@EXPORT_OK, [qw(try catch finally)], 'our @EXPORT_OK is an independent copy');

# --- our, deep chain ---
our @P = our @Q = our @R = (10, 20);
is_deeply(\@P, [10, 20], 'deep chain: @P');
is_deeply(\@Q, [10, 20], 'deep chain: @Q');
is_deeply(\@R, [10, 20], 'deep chain: @R');

# --- our, scalar ---
our $x = our $y = 5;
is($x, 5, 'our $x');
is($y, 5, 'our $y');

# --- our, hash (independent copies) ---
our %h = our %g = (a => 1, b => 2);
is_deeply(\%h, { a => 1, b => 2 }, 'our %h gets the pairs');
is_deeply(\%g, { a => 1, b => 2 }, 'our %g gets the pairs');
$h{c} = 3;
ok(!exists $g{c}, 'our %g unaffected by $h{c}=... (independent copy)');

# --- our @A = @B is a copy too (the building block) ---
our @src = (7, 8, 9);
our @dst = @src;
push @dst, 0;
is_deeply(\@src, [7, 8, 9], 'our @dst = @src is a copy, not an alias');

done_testing;
