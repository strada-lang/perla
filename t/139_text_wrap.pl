#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native Text::Wrap (the real .pm doesn't run under perla, so wrap/fill were
# undefined). Covers greedy wrap, $initial/$subsequent tabs, $columns,
# huge='wrap'/'overflow', tab expand, unexpand (default on), separator, fill.
use Text::Wrap qw(wrap fill $columns $huge);

$Text::Wrap::columns = 20;
is(wrap("", "", "The quick brown fox jumps over the lazy dog"),
   "The quick brown fox\njumps over the lazy\ndog",
   "greedy wrap at columns");

is(wrap(">> ", "   ", "The quick brown fox jumps over the lazy dog"),
   ">> The quick brown\n   fox jumps over\n   the lazy dog",
   "initial + subsequent tabs; columns count the prefix");

$Text::Wrap::columns = 10;
is(wrap("", "", "supercalifragilistic"),
   "supercali\nfragilist\nic",
   "huge word force-broken (huge='wrap')");

{
    local $Text::Wrap::huge = 'overflow';
    local $Text::Wrap::columns = 8;
    is(wrap("", "", "abcdefghijkl mno"),
       "abcdefghijkl\nmno",
       "huge='overflow' keeps the long word whole");
}

# short text fits on one line unchanged
$Text::Wrap::columns = 76;
is(wrap("", "", "short text"), "short text", "text under columns is unchanged");

# custom separator
{
    local $Text::Wrap::separator = "|";
    local $Text::Wrap::columns = 15;
    is(wrap("", "", "one two three four five"),
       "one two three|four five",
       "custom \$separator");
}

# unexpand (default on): a >=tabstop space lead collapses to a tab
{
    local $Text::Wrap::columns = 40;
    my $out = wrap((" " x 10), (" " x 10), "alpha beta gamma delta epsilon zeta");
    like($out, qr/\t/, "unexpand turns the 10-space lead into a tab (default)");
    local $Text::Wrap::unexpand = 0;
    my $out2 = wrap((" " x 10), (" " x 10), "alpha beta gamma");
    unlike($out2, qr/\t/, "unexpand=0 keeps spaces");
}

# tab in the input is expanded for column math
{
    local $Text::Wrap::columns = 20;
    my $out = wrap("", "", "col1\tcol2 word word word");
    is($out, "col1\tcol2 word\nword word", "input tab expanded then re-unexpanded");
}

# fill: reflow paragraphs, collapse internal whitespace, blank line between
$Text::Wrap::columns = 30;
is(fill("", "", "one two three\nfour five\n\nsix seven"),
   "one two three four five\n\nsix seven",
   "fill reflows + separates paragraphs");

# multi-arg text is space-joined
is(wrap("", "", "alpha ", "beta ", "gamma"), "alpha beta gamma", "multi-arg text joined");

done_testing;
