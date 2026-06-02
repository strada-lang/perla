#!/usr/bin/perl
use warnings;
use Test::More;

# `my $x = func(%$href)` (or `(@_, %$href)` etc.) — when the outer
# context is scalar (e.g. assigning the call's return to a scalar),
# __perla_want_list was 0 at the time the call's arg list was
# evaluated. The N_DEREF_HASH branch in `_gen_push_args` (and in the
# parenthesized-list N_ANON_ARRAY flatten) then emitted code that
# consulted that scalar-context flag — `%$href` in scalar context
# returns the bucket-count tag-int instead of the hash itself.
# strada_deref_hash on a tagged int is NULL, the iteration loop
# pushed nothing, and the callee saw 0 args.
#
# Concrete victim: validators like
#   my $err = validate(%$params);
# where the validator dispatches on `defined $params{name}` and
# returned "name required" for every input because %$params was
# silently dropped.

sub count_args { scalar @_ }

# In scalar context (assignment to scalar)
{
    my $h = { a => 1, b => 2, c => 3 };
    my $n = count_args(%$h);
    is($n, 6, "(%\$href) flattens to 6 args (3 pairs) in scalar ctx");

    my $n2 = count_args(%$h, %$h);
    is($n2, 12, "two %\$href flattenings concat to 12 args");
}

# In list context (assignment to array)
{
    my $h = { x => 10 };
    my @r;
    @r = count_args(%$h);
    is($r[0], 2, "%\$href flattens to 2 args in list ctx");
}

# Inline construction
{
    sub gen_h { return { p => "P", q => "Q" } }
    my $n = count_args(%{gen_h()});
    is($n, 4, "%{call()} flattens correctly even in scalar ctx");
}

# Validator pattern (the reported bug)
sub validate {
    my %params = @_;
    return "name required" unless defined $params{name};
    return "age required" unless defined $params{age};
    return;
}

{
    my $t = { name => "Alice", age => 30 };
    my $err = validate(%$t);
    is($err, undef, "validate(%\$t) sees both params (no error)");

    my $t2 = { name => "Bob" };
    my $err2 = validate(%$t2);
    is($err2, "age required", "validate(%\$t2) flags missing age");

    my $t3 = { age => 99 };
    my $err3 = validate(%$t3);
    is($err3, "name required", "validate(%\$t3) flags missing name");
}

done_testing;
