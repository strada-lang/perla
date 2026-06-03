#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# The `@{[ EXPR ]}` "babycart" list-interpolation idiom must NOT consume the
# aggregate it interpolates. perla's babycart joined the inner array then
# unconditionally strada_decref'd it -- but for a borrowed aggregate (a bare
# @arr, @$ref, or %h) gen_expr hands back the variable's own backbone without
# an incref, so the decref dropped its last ref and FREED it. Result: the
# string came out right but the source array was left EMPTY afterward.

# bare array
my @arr = (1, 2, 3);
my $s1 = "@{[ @arr ]}";
is($s1, "1 2 3", 'babycart over @arr produces correct string');
is(scalar(@arr), 3, '@arr not emptied by babycart');

# array deref
my $aref = [4, 5, 6];
my $s2 = "@{[ @$aref ]}";
is($s2, "4 5 6", 'babycart over @$ref produces correct string');
is(scalar(@$aref), 3, '@$ref not emptied by babycart');

# postfix deref
my $pref = [7, 8, 9];
my $s3 = "@{[ $pref->@* ]}";
is($s3, "7 8 9", 'babycart over $ref->@* produces correct string');
is(scalar(@$pref), 3, '$ref->@* not emptied by babycart');
is($pref->$#*, 2, '$ref->$#* correct after babycart');

# postfix slice in babycart
my $sref = [10, 20, 30, 40];
is("@{[ $sref->@[1,3] ]}", "20 40", 'babycart over $ref->@[..] slice');
is(scalar(@$sref), 4, '$ref->@[..] not emptied');

# same aggregate twice in one string
my $tref = [1, 2, 3];
is("@{[ @$tref ]}|@{[ @$tref ]}", "1 2 3|1 2 3", 'two babycarts over same ref both work');
is(scalar(@$tref), 3, 'ref intact after two babycarts');

# owned inner (map/grep) still works and is freed (no leak, no corruption)
my @src = (1, 2, 3);
is("@{[ map { $_ * 2 } @src ]}", "2 4 6", 'babycart over map still works');
is(scalar(@src), 3, 'map source intact');

done_testing;
