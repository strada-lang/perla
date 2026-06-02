#!/usr/bin/perl
use warnings;
use Test::More;

# `SKIP: { skip $reason, $count; fail("…"); ... }` — when skip() is
# called inside a SKIP block, every subsequent ok/is/like/fail in
# the same block must be a no-op (perl's `last SKIP` semantics).
# The historical perla runtime had `perla_tm_print_ok` honor the
# in-skip flag, but `perla_tm_print_fail_detail` (called separately
# by `fail`, `is`, `like`, etc. for the "#   Failed test …" line)
# did not. So `fail("oops")` after a skip would no-op the ok line
# but still print `#   Failed test 'oops'` — TAP-noisy and confusing.
#
# Bare-block label semantics already let `last SKIP` work for source
# that uses it explicitly; this guard rescues the common idiomatic
# `skip $reason, $count;` followed by code that would have run.

ok(1, "before SKIP");
SKIP: {
    skip "skip rest", 2;
    fail("should not run a");
    fail("should not run b");
    is(1, 2, "should not run c");
    like("x", qr/y/, "should not run d");
}
ok(1, "after SKIP");
done_testing;
