#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# List::Util::uniqint — truncates each value to an integer, removes
# subsequent duplicate integers, and returns those integers (not the
# originals), in first-seen order. perla had uniq/uniqstr/uniqnum but
# uniqint was unregistered (returned empty).
use List::Util qw(uniqint uniq uniqnum);

is_deeply([uniqint(1, 1, 2, 3, 3)], [1, 2, 3], "removes duplicate ints");
is_deeply([uniqint(1, 1.0, 2.9, 3)], [1, 2, 3], "truncates toward zero, dedups");
is_deeply([uniqint(-2.9, -2, 5.1, 5, 0, -0.5)], [-2, 5, 0], "negatives truncate toward zero");
is_deeply([uniqint()], [], "empty list");
is_deeply([uniqint(7)], [7], "single value");
is_deeply([uniqint(3, 1, 2, 1, 3)], [3, 1, 2], "preserves first-seen order");

# output values are integers, not the originals (2.9 -> 2)
my @r = uniqint(2.9, 2.1);
is(scalar(@r), 1, "2.9 and 2.1 collapse to one int");
is($r[0], 2, "the kept value is the truncated integer 2");

# uniq / uniqnum still behave (regression guard)
is_deeply([uniq(1, 1, 2)], [1, 2], "uniq still works");
is_deeply([uniqnum(1, 1.0, 2)], [1, 2], "uniqnum still works");

done_testing;
