#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# JSON::PP::Boolean (the objects decode produces for true/false, and the
# JSON::PP::true / ::false constants) must stringify to "1"/"0", numify to
# 1/0, and behave as booleans — not stringify to "JSON::PP::Boolean=...".
use JSON::PP;

my $d = JSON::PP->new->decode('[true, false]');
my ($t, $f) = @$d;

is(ref($t), "JSON::PP::Boolean", "decoded true is a JSON::PP::Boolean");
is("$t", "1", "true stringifies to 1");
is("$f", "0", "false stringifies to 0");
is($t + 0, 1, "true numifies to 1");
is($f + 0, 0, "false numifies to 0");
ok($t, "true is truthy");
ok(!$f, "false is falsy");

# the exported constants share the class + overloads
is("" . JSON::PP::true,  "1", "JSON::PP::true stringifies to 1");
is("" . JSON::PP::false, "0", "JSON::PP::false stringifies to 0");

# string interpolation inside a larger string
is("val=$t/$f", "val=1/0", "booleans interpolate");

# round-trips back to true/false (encoder recognizes the class)
is(JSON::PP->new->canonical->encode({ ok => $t, no => $f }),
   '{"no":false,"ok":true}', "encode round-trips booleans");

done_testing;
