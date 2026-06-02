#!/usr/bin/perl
use warnings;
use Test::More;

# Same root issue as the SUB-as-first-arg fix: the bare-IDENT no-paren
# call branch was missing DO, QW, and MY from the accepted follow-up
# token types. So:
#
#   takes_one do { 1+2+3 };  # parsed as takes_one() + do-block dropped
#   takes_one qw(a b c);     # parsed as takes_one() + qw() dropped
#   takes_one my $x = "hi";  # parsed as takes_one() + my-decl dropped
#
# Test::More's `is(EXPR, EXPR, DESC)` works because `is` is in the
# named-unary table for `_parse_concat`; user-defined wrappers fall
# through to the generic no-paren branch and need these tokens.

sub takes_one { $_[0] }

# do-block as first arg
{
    my $r = takes_one do { 1 + 2 + 3 };
    is($r, 6, "takes_one do { EXPR } passes the block's value");
    my $h = takes_one do { { a => 1, b => 2 } };
    is_deeply($h, { a => 1, b => 2 }, "takes_one do { ANON_HASH }");
}

# qw() as first arg — perl's named-unary semantics give the first item
{
    sub takes_first { my @a = @_; "got " . scalar(@a) . " items" }
    my $r = takes_first qw(red green blue);
    like($r, qr/got 3 items/, "takes_first qw(a b c) passes all three");
}

# my-decl as first arg
{
    sub takes_one2 { $_[0] }
    my $rv = takes_one2 my $val = "world";
    is($val, "world", "the my-decl actually initialised \$val");
    is($rv,  "world", "and the call returned that value as arg");
}

# Mixed with @_ list
{
    sub my_two { $_[0] . "|" . ($_[1] // "_") }
    is(my_two(do { "left" }, "right"), "left|right",
        "two-arg with do-block as first wrapped in parens");
}

done_testing;
