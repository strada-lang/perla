#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `sort $coderef LIST` where $coderef is a block-scoped `my` lexical: the
# Collect/rename pass didn't descend into the sort's comparator_expr, so the
# block-renamed lexical was left unrenamed and strict-mode resolution failed
# ("Global symbol $cmp requires explicit package name"). Other block-lexical
# uses (->(), map, grep) already worked; only sort's scalar comparator broke.

# block-scoped coderef comparator
{
    my $cmp = sub { $a <=> $b };
    is_deeply([sort $cmp (3, 1, 2, 10)], [1, 2, 3, 10], "block-scoped \$cmp ascending");
}

# block-scoped reverse comparator over an array var
{
    my $rev = sub { $b <=> $a };
    my @x = (1, 3, 2);
    is_deeply([sort $rev @x], [3, 2, 1], "block-scoped \$rev over \@x");
}

# nested block shadowing — inner $cmp differs from outer
my $cmp = sub { $a <=> $b };
{
    my $cmp = sub { $b <=> $a };
    is_deeply([sort $cmp (1, 3, 2)], [3, 2, 1], "inner block \$cmp (reverse)");
}
is_deeply([sort $cmp (3, 1, 2)], [1, 2, 3], "outer \$cmp still ascending after block");

# inside a sub body (also a nested scope)
sub run_sort {
    my $by = sub { $a <=> $b };
    return sort $by @_;
}
is_deeply([run_sort(5, 2, 8, 1)], [1, 2, 5, 8], "block-scoped \$cmp inside a sub");

# regression: top-level coderef + string-key cmp comparator
my $bylen = sub { length($a) <=> length($b) };
is_deeply([sort $bylen qw(ccc a bb)], [qw(a bb ccc)], "top-level coderef by length");

done_testing;
