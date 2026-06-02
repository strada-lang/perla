#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Final sort-comparator forms:
#  - `sort($coderef LIST)` — a coderef comparator inside sort's immediate
#    parens (the paren branch previously only special-cased a bareword sub).
#  - a double-quoted string list after a comparator (DQSTRING token was not
#    in the list-starter set, so the comparator stringified into the output).

my $numdesc = sub { $b <=> $a };
my $strasc  = sub { $a cmp $b };
sub bydesc { $b <=> $a }

# coderef comparator inside sort's parens
is_deeply([sort($numdesc 3, 1, 2)],  [3, 2, 1], "sort(\$cmp comma-list)");
my @arr = (3, 1, 2, 10);
is_deeply([sort($numdesc @arr)],     [10, 3, 2, 1], "sort(\$cmp \@arr)");
is_deeply([sort($numdesc 1, @arr)],  [10, 3, 2, 1, 1], "sort(\$cmp mixed list)");

# double-quoted string list after a comparator
is_deeply([sort $strasc "z", "a", "m"],  [qw(a m z)], "coderef + double-quoted list");
is_deeply([sort bydesc 30, 4, 200],      [200, 30, 4], "named + numeric list (sanity)");
is_deeply([sort $strasc "banana", "apple"], [qw(apple banana)], "two dq strings");

# regression: sort($list) with no comparator is a plain list sort
my ($p, $q) = (3, 1);
is_deeply([sort($p, $q, 2)], [1, 2, 3], "sort(\$x, \$y, ...) plain list sort");
is_deeply([sort(bydesc 3, 1, 2)], [3, 2, 1], "sort(bareword comma-list) still works");

# regression: single-quoted list still works (STRING token)
is_deeply([sort $strasc 'pear', 'fig', 'kiwi'], [qw(fig kiwi pear)], "single-quoted list");

done_testing;
