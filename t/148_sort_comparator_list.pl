#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# The LIST after a no-paren sort comparator (named sub or $coderef) is a
# full comma-separated list — and may begin with a short array/hash deref
# (@$ref / %$ref). perla previously parsed only the first element (leaking
# the rest to the enclosing call) and didn't recognize @$ref / %$ref as a
# list-starter (so the comparator stringified into the output).

my $desc = sub { $b <=> $a };
sub bydesc { $b <=> $a }

# bare comma list after the comparator
is_deeply([sort $desc 3, 1, 2],   [3, 2, 1], "coderef + bare comma list");
is_deeply([sort bydesc 3, 1, 2],  [3, 2, 1], "named sub + bare comma list");
is_deeply([sort $desc 5],         [5],       "single-element list");

# the comparator consumes the whole comma list, not just the first element
is(join("|", sort $desc 3, 1, 2), "3|2|1", "whole list sorted (no leak)");

# short array deref @$ref as the list
my $aref = [3, 1, 2, 10];
is_deeply([sort $desc @$aref],  [10, 3, 2, 1], "coderef + \@\$ref");
is_deeply([sort bydesc @$aref], [10, 3, 2, 1], "named + \@\$ref");

# hash short deref via values %$href
my $href = { a => 3, b => 1, c => 2 };
is_deeply([sort $desc values %$href], [3, 2, 1], "coderef + values %\$href");

# deref list inside a map block (nested scope)
my @rows = ([3, 1], [2, 4]);
is_deeply([map { join(",", sort $desc @$_) } @rows], ["3,1", "4,2"], "sort \$cmp \@\$_ inside map");

# vars + exprs mixed in the comma list
my ($x, $y) = (1, 9);
is_deeply([sort bydesc $x, $y, 5], [9, 5, 1], "named + mixed vars/literals list");

# regressions: parens, array var, block form still work
is_deeply([sort $desc (3, 1, 2)], [3, 2, 1], "paren list");
is_deeply([sort { $b <=> $a } @$aref], [10, 3, 2, 1], "block form + \@\$ref");

done_testing;
