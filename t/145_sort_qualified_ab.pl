#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# sort comparator $a/$b are package globals: a comparator that reads them
# qualified ($main::a / $::a) or lives in another package (sort Foo::cmp,
# referencing $main::a) must see the values. perla published $a/$b only as
# C locals, so qualified/cross-package reads got undef and the list came
# back unsorted. Now the sort thunks also set the main:: stash slots.

# top-level coderef comparator reading $main::a / $main::b
my $cmp_num = sub { $main::a <=> $main::b };
is_deeply([sort $cmp_num (4, 2, 6, 1)], [1, 2, 4, 6], "coderef comparator, \$main::a");

my $cmp_rev = sub { $::b <=> $::a };
is_deeply([sort $cmp_rev (1, 3, 2)], [3, 2, 1], "coderef, \$::a / \$::b reverse");

# named main comparator reading $main::a qualified
sub bynum_q { $main::a <=> $main::b }
is_deeply([sort bynum_q (5, 2, 8, 1)], [1, 2, 5, 8], "named comparator, qualified \$main::a");

# cross-package named comparator using $main::a
package Cmp1;
sub bynum { $main::a <=> $main::b }
sub byrev { $::b <=> $::a }
package main;
is_deeply([sort Cmp1::bynum (3, 1, 2, 10)], [1, 2, 3, 10], "cross-pkg sort, \$main::a");
is_deeply([sort Cmp1::byrev (3, 1, 2)], [3, 2, 1], "cross-pkg sort, \$::b reverse");

# regression: same-package bare $a/$b and block forms still work
sub plain { $a <=> $b }
is_deeply([sort plain (3, 1, 2)], [1, 2, 3], "same-pkg bare \$a/\$b");
is_deeply([sort { $b <=> $a } (1, 3, 2)], [3, 2, 1], "block comparator");
is_deeply([sort qw(banana apple cherry)], [qw(apple banana cherry)], "default string sort");

done_testing;
