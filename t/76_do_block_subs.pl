use strict;
use warnings;

# `my $x = do { sub NAME { ... } NAME(args); }` — Perl hoists the
# named sub into the enclosing package at compile time, so the call
# inside the do-block resolves correctly and $x gets the call's value.

my $val_1 = do {
    sub double { $_[0] * 2 }
    double(7);
};
die "1: got '$val_1'" unless $val_1 == 14;

my $val_2 = do {
    sub triple { $_[0] * 3 }
    my $r = triple(8);
    $r;
};
die "2: got '$val_2'" unless $val_2 == 24;

my $val_3 = do {
    sub q1 { 11 }
    sub q2 { 22 }
    q2();
};
die "3: got '$val_3'" unless $val_3 == 22;

# Sub is callable from outside the do-block too (Perl hoist).
die "4: outside" unless double(5) == 10;
die "4: outside" unless triple(5) == 15;

# Lexical sub still works.
use feature 'lexical_subs';
no warnings 'experimental::lexical_subs';
my $val_4 = do {
    my sub quadruple { $_[0] * 4 }
    quadruple(7);
};
die "4: got '$val_4'" unless $val_4 == 28;

print "ok\n";
