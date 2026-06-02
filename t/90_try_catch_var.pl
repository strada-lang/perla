#!/usr/bin/perl
use warnings;
use Test::More;
use feature 'try';
no warnings 'experimental::try';

# `try { ... } catch ($var) { ... } finally { ... }` — perl 5.34 try/
# catch syntax with explicit catch variable. The historical parser
# treated `catch` as a block-first builtin requiring `{...}` straight
# after, so `catch ($e)` left $e unbound (catch body ran with empty
# value) and the trailing `finally { }` was orphaned as a separate
# statement. Now the parser walks a tail of `catch (VAR)? { ... }` /
# `finally { ... }` clauses after a `try { ... }`.

# Basic catch ($var)
{
    my $r = eval {
        try {
            die "boom\n";
        } catch ($e) {
            return "caught: $e";
        }
    };
    like($r, qr/caught: boom/, "catch (\$e) binds the exception value");
}

# Catch + finally — finally runs after catch
{
    my @log;
    try {
        push @log, "try";
        die "oops\n";
    } catch ($e) {
        push @log, "catch:$e";
    } finally {
        push @log, "finally";
    }
    is($log[0], "try", "try ran");
    like($log[1], qr/^catch:oops/, "catch ran with bound \$e");
    is($log[2], "finally", "finally ran after catch");
}

# Try with no exception still runs finally
{
    my @log;
    try {
        push @log, "try-ok";
    } catch ($e) {
        push @log, "catch-skipped";
    } finally {
        push @log, "finally-ok";
    }
    is($log[0], "try-ok", "try-ok ran");
    is($log[1], "finally-ok", "finally runs on success too");
    is(scalar(@log), 2, "catch did not run when no exception");
}

# Catch with blessed exception
{
    eval {
        try {
            die bless { code => 500, msg => "server" }, "Err";
        } catch ($e) {
            is(ref($e), "Err", "blessed exception preserved in catch");
            is($e->{code}, 500, "exception field accessible");
        }
    };
}

# Catch variable doesn't leak after block
{
    our $outer_e = "outer";
    eval {
        try {
            die "inner\n";
        } catch ($outer_e) {
            is($outer_e, "inner\n", "catch var sees exception in block");
        }
    };
    is($outer_e, "outer", "catch var restored after block");
}

done_testing;
