#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Regression: arithmetic/concat on the LHS of a comparison must NOT be
# folded into a Perl-5.32 comparison chain. `$x + $y == N` is
# `($x + $y) == N`, not `($x+$y truthy) && ($y == N)`. (Earlier the
# chained-comparison promotion defaulted any binop LHS to the equality
# tier, so `+ * % .` mis-chained; `- /` only looked right by coincidence
# when the middle operand matched the RHS.)
my ($x, $y) = (4, 2);
ok($x + $y == 6,  '+ on LHS of ==');
ok($x - $y == 2,  '- on LHS of ==');
ok($x * $y == 8,  '* on LHS of ==');
ok($x / $y == 2,  '/ on LHS of ==');
ok($x % $y == 0,  '% on LHS of ==');
ok(2 ** 3 == 8,   '** on LHS of ==');
ok("4"."2" == 42, '. (concat) on LHS of ==');
ok(!($x + $y == 7), '+ on LHS, false case');
ok(!($x % $y == 1), '% on LHS, false case');

# grep/map blocks with `%` predicates (the original symptom).
my @evens = grep { $_ % 2 == 0 } 1..10;
is("@evens", "2 4 6 8 10", 'grep { $_ % 2 == 0 }');
my @odds  = grep { $_ % 2 == 1 } 1..10;
is("@odds", "1 3 5 7 9", 'grep { $_ % 2 == 1 }');

# Genuine Perl-5.32 chained comparisons must STILL work.
ok(1 < 2 < 3,        'chain 1 < 2 < 3 true');
ok(!(3 < 2 < 1),     'chain 3 < 2 < 1 false');
ok(1 <= 1 <= 2,      'chain <= true');
ok(!(5 == 5 == 1),   'chain == folds (5==5)&&(5==1) -> false');
{
    my $n = 5;
    ok(1 <= $n <= 10,  'range chain 1 <= $n <= 10');
    ok(!(1 <= 20 <= 10), 'range chain out of range');
}

# Mixed: comparison whose operand is itself arithmetic, chained.
ok(0 < $x % 3 < 5,   'chain with arithmetic middle operand');

done_testing;
