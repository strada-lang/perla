#!/usr/bin/perl
use warnings;
use Test::More;

# `subtest NAME => sub { ... }` — perl 5.16+ runs the body in a nested
# context with its own counter, indented TAP output, and a final
# `1..N` inner plan; on exit the parent counter ticks up by 1 ok M -
# NAME (or not ok if any inner assertion failed). perla previously
# didn't implement subtest at all — the body was called as a normal
# coderef but with the parent's counter, producing flat output and
# no parent-level ok line, which Test::Harness/prove couldn't parse
# as nested results.
#
# This file exercises subtest end-to-end. If subtest's TAP output is
# structurally wrong (no `# Subtest:` header, no indented children,
# no inner plan, no parent ok line), Test::Harness still sees a
# valid stream because each child ok increments the counter, BUT
# nested test files wouldn't be reusable as `prove -r` units. The
# best functional verification within Test::More itself is: did the
# inner ok/is run, and did the parent ok increment correctly.

# Inside a subtest, assertions execute and contribute to subtest's
# pass/fail. The outer counter gets ONE tick (the subtest itself).
my $inner_ok = 0;
my $inner_fail = 0;
subtest 'group_1' => sub {
    $inner_ok++; ok(1, "inner 1");
    $inner_ok++; ok(1, "inner 2");
    $inner_ok++; ok(1, "inner 3");
};
is($inner_ok, 3, "all 3 inner assertions ran (body fully executed)");

# Nested
subtest 'outer' => sub {
    ok(1, "outer 1");
    subtest 'inner' => sub {
        ok(1, "deep 1");
        ok(1, "deep 2");
    };
    ok(1, "outer 2");
};

# Subtest with failure — parent ok counts a "not ok"
my $failed_subtest = 0;
my $r = subtest 'failing' => sub {
    ok(1);
    fail("intentional");
};
ok(!$r, "subtest with failure returns false");

# Subtest return value
my $rv = subtest 'returns_truthy' => sub {
    ok(1);
};
ok($rv, "subtest returning all-pass returns true");

done_testing;
