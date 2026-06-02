#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# A successful regex match records only the subject + offset vector; the
# captures array / %+ / @- / @+ / $`/$' are materialized lazily on first
# access (a match used purely as a boolean allocates nothing). These
# assertions lock the semantics that lazy materialization must preserve:
# deferred access, preserve-on-failure, no-group clearing, and that every
# derived variable agrees with an eager build.

# --- deferred access: capture read long after the match ---
"the answer is 42 today" =~ /(\d+)/;
my $later = $1;                       # accessed after the match statement
is($later, 42, '$1 readable after the match statement (lazy build)');

# --- $&, $`, $' ---
ok("abcXYZdef" =~ /XYZ/, 'plain match');
is($&, "XYZ", '$& whole match');
is($`, "abc",  '$` prematch (built on access)');
is($', "def",  q{$' postmatch (built on access)});

# --- multiple numbered groups + $+ (last paren) ---
ok("2026-06-01" =~ /(\d+)-(\d+)-(\d+)/, 'date match');
is("$1/$2/$3", "2026/06/01", '$1..$3');
is($+, "01", '$+ is last matched group');

# --- @- / @+ offsets (built on access) ---
ok("hello world" =~ /(\w+)\s+(\w+)/, 'two words');
is($-[0], 0,  '@-[0] whole-match start');
is($+[0], 11, '@+[0] whole-match end');
is($-[1], 0,  '@-[1] group 1 start');
is($+[2], 11, '@+[2] group 2 end');

# --- named captures %+ ---
ok("user=bob" =~ /(?<key>\w+)=(?<val>\w+)/, 'named match');
is($+{key}, "user", '%+ key');
is($+{val}, "bob",  '%+ val');

# --- preserve-on-failure: $1 survives a subsequent FAILED match ---
"abc123" =~ /([a-z]+)(\d+)/;
is("$1-$2", "abc-123", 'captures set');
my $failed = ("ZZZ" =~ /(\d+)/);
ok(!$failed, 'second match fails');
is("$1-$2", "abc-123", '$1/$2 preserved across the failed match');

# --- success with NO capture group clears $1 ---
ok("xyzzy" =~ /xyz/, 'no-group match succeeds');
ok(!defined $1, '$1 cleared after a no-group successful match');

# --- a boolean-only match (never accessing captures) still updates $&
#     for the NEXT access, and a following capture match overrides it ---
my $n = 0;
for my $i (1 .. 4) { $n++ if "row $i" =~ /\d/; }   # boolean, captures untouched
is($n, 4, 'boolean matches in a loop');
"final 7" =~ /(\d+)/;
is($1, 7, 'capture after a run of boolean matches');

# --- /g list context + captures() interplay ---
my @nums = ("a1b2c3" =~ /(\d)/g);
is("@nums", "1 2 3", '/g list-context captures');

# --- captures persist when stored, across an intervening match ---
my %store;
"id=100" =~ /=(\d+)/; $store{a} = $1;
"id=200" =~ /=(\d+)/; $store{b} = $1;
is("$store{a},$store{b}", "100,200", 'stored captures unaffected by later match');

done_testing;
