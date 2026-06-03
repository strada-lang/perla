#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# An inline `my` on an individual element of a list-destructure assignment LHS
# -- ($foo, my $x) = LIST -- must declare $x in the enclosing scope, the same
# as my (..., $x) = LIST. perla buried the `my` in the N_ANON_ARRAY target and
# never registered/declared the var, so a later reference tripped strict 'vars'
# both at file scope and inside a sub. Surfaced by DBIx::Class::ResultSet.

sub pair { return ("G", "O"); }
sub triple { return (1, 2, 3); }

my %a; ($a{x}, my $y) = pair();
is($y, "O", 'inline my at file scope gets the second element');
is($a{x}, "G", 'preceding hash-elem lvalue still assigned');

my @arr; ($arr[0], my $z, my $w) = triple();
is("$arr[0]/$z/$w", "1/2/3", 'multiple inline my at file scope');

sub doit { my %h; ($h{k}, my $v) = pair(); return "$h{k}-$v"; }
is(doit(), "G-O", 'inline my inside a sub');

sub later { my $sum = ""; ($sum, my $tail) = ("X", "Y"); return "$sum$tail-$sum"; }
is(later(), "XY-X", 'inline my var visible to later statements in the sub');

sub slurp { my $head; ($head, my @rest) = (10, 20, 30, 40); return $head . ":" . join(",", @rest); }
is(slurp(), "10:20,30,40", 'inline my @array slurps the remainder');

done_testing;
