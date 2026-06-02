#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Postfix-deref last-index `$ref->$#*` (Perl 5.24+), equivalent to $#{$ref}.
# The rest of the postfix-deref family (->@*, ->%*, ->$*, ->@[...], ->@{...})
# already worked; ->$#* was unparsed and cascaded into a parse error.

my $aref = [10, 20, 30, 40];
is($aref->$#*, 3, "->\$#* gives last index");
is($#{$aref}, 3, "\$#{...} braced form agrees");
is($aref->$#*, $#{$aref}, "postfix and braced match");

my $empty = [];
is($empty->$#*, -1, "->\$#* of empty array is -1");

my $one = ["x"];
is($one->$#*, 0, "->\$#* of single-element array is 0");

# in expressions
my $n = $aref->$#*;
is($n, 3, "assignable to a scalar");
is($aref->$#* + 1, 4, "usable in arithmetic (count)");

# chained off a nested structure
my $data = { list => [1, 2, 3, 4, 5] };
is($data->{list}->$#*, 4, "->\$#* off a hash-element arrayref");

# iterate by index using ->$#*
my @collected;
for my $i (0 .. $aref->$#*) { push @collected, $aref->[$i]; }
is("@collected", "10 20 30 40", "0..\$ref->\$#* iterates all elements");

# coexists with the other postfix-deref forms in one program
is(join(",", $aref->@*), "10,20,30,40", "->\@* still works alongside");

done_testing;
