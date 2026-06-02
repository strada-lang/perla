#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# version.pm: dotted/v-string and decimal forms normalize to comparable
# component tuples — "1.2.3" < "1.10.0" (NOT string/float coercion), with
# correct numify/normal rendering.
use version;

# numeric comparison (the core fix — float coercion gave 1.2 > 1.1)
ok(version->parse("1.2.3") < version->parse("1.10.0"), "1.2.3 < 1.10.0");
is(version->parse("1.2.3") <=> version->parse("1.10.0"), -1, "spaceship lt");
ok(version->parse("2.0.0") > version->parse("1.99.99"), "2.0.0 > 1.99.99");
ok(version->parse("1.2.3.4") > version->parse("1.2.3"), "longer tuple wins on tie prefix");

# decimal vs dotted differ: 1.20 -> [1,200], 1.20.0 -> [1,20,0]
ok(version->parse("1.20") != version->parse("1.20.0"), "1.20 != 1.20.0");
ok(version->parse("1.20") > version->parse("1.20.0"), "1.20 > 1.20.0");

# 1.20 == 1.20.0 must be false (the previously-wrong 'eq' case)
ok(!(version->parse("1.20") == version->parse("1.20.0")), "1.20 == 1.20.0 is false");

# equality of equivalent forms
ok(version->parse("1.2.3") == version->parse("v1.2.3"), "1.2.3 == v1.2.3");
ok(version->parse("1.002003") == version->parse("1.2.3"), "1.002003 == 1.2.3");

# numify
is(version->parse("1.2.3")->numify,    "1.002003",    "numify dotted");
is(version->parse("1.10.0")->numify,   "1.010000",    "numify with 10");
is(version->parse("1.20")->numify,     "1.200",       "numify decimal");
is(version->parse("1.2.3.4")->numify,  "1.002003004", "numify 4 parts");
is(version->parse("2")->numify,        "2.000",       "numify bare int");

# normal
is(version->parse("1.2.3")->normal,  "v1.2.3",   "normal dotted");
is(version->parse("1.20")->normal,   "v1.200.0", "normal decimal");
is(version->parse("v1.2")->normal,   "v1.2.0",   "normal v-string padded");
is(version->parse("1")->normal,      "v1.0.0",   "normal bare int");

# stringify returns the original
is("" . version->parse("1.2.3"),  "1.2.3",  "stringify keeps original");
is("" . version->parse("v1.2.3"), "v1.2.3", "stringify keeps v prefix");

# comparison against a plain number coerces it as a version
ok(version->parse("1.2.3") < 1.5, "version < plain number");

done_testing;
