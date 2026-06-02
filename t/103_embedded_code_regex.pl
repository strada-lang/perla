#!/usr/bin/perl
use warnings;
use Test::More;

# `(?{ CODE })` embedded code blocks. Perl runs CODE during matching;
# PCRE2 has no equivalent, so perla strips the blocks from the pattern
# and runs their code after a successful match, with the captures in
# place. Exact for the common single-shot use; the strip+post-run only
# activates when `(?{` appears, so ordinary regexes are untouched.

# Code sees captures
{
    our $n;
    "abc123" =~ /(\d+)(?{ $n = "set:$1" })/;
    is($n, "set:123", "(?{ }) sees \$1 capture");
}

# Multiple blocks both run, in order
{
    our $cnt = 0;
    "xx" =~ /x(?{ $cnt++ })x(?{ $cnt += 10 })/;
    is($cnt, 11, "two (?{ }) blocks both run");
}

# Mid-pattern, no captures
{
    my $hit = 0;
    "hello" =~ /ell(?{ $hit = 1 })/;
    is($hit, 1, "(?{ }) runs on a successful match without captures");
}

# Code does NOT run when the match fails
{
    my $ran = 0;
    "abc" =~ /(\d+)(?{ $ran = 1 })/;
    is($ran, 0, "(?{ }) does not run when the overall match fails");
}

# Block at end after a capture group, with following literal
{
    our $w;
    "key=value" =~ /(\w+)=(?{ $w = $1 })(\w+)/;
    is($w, "key", "(?{ }) mid-pattern sees the prior capture");
    is($1, "key", "trailing capture group still works");
    is($2, "value", "capture after (?{ }) still works");
}

done_testing;
