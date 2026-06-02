#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# sprintf positional value + positional dynamic width/precision (%2$*1$d):
# the width/precision `*N$` references argument N. perla's format parser
# consumed the `*` but not the `N$` index, so `1$d` was mis-read as the
# conversion char and the spec rendered as garbage ("%51$d").

is(sprintf("%2\$*1\$d", 5, 42),   "   42", "positional value + positional width");
is(sprintf("%1\$*2\$d", 42, 5),   "   42", "value arg 1, width arg 2");
is(sprintf("%2\$-*1\$d", 5, 42),  "42   ", "left-justify flag with positional width");
is(sprintf("%.*2\$f", 3.14159, 2), "3.14", "positional precision .*N\$");
is(sprintf("%2\$.*1\$f", 3, 3.14159), "3.142", "positional value + positional precision");
is(sprintf("%2\$*1\$.*3\$f", 8, 3.14159, 2), "    3.14", "width arg1, value arg2, prec arg3");

# plain (non-positional) dynamic width/precision still work
is(sprintf("%*d", 6, 7), "     7", "plain dynamic width");
is(sprintf("%.*f", 2, 3.14159), "3.14", "plain dynamic precision");
is(sprintf("%*.*f", 8, 2, 3.14159), "    3.14", "plain dynamic width + precision");

# plain positional (no star) still works
is(sprintf("%2\$d %1\$d", 10, 20), "20 10", "plain positional reorder");
is(sprintf("%1\$s-%1\$s", "x"), "x-x", "reused positional");

done_testing;
