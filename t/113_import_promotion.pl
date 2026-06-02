#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `use Module qw(names)` must promote the imported names into the
# caller's stash (so `defined &main::NAME`, `main->can('NAME')`, and
# `\&NAME` work), not merely make them callable via a global fallback.
# Previously several builtin module shims registered their subs only in
# their own stash with no Exporter wiring, so the names never landed in
# the caller.
use Scalar::Util qw(blessed reftype looks_like_number);
use Storable qw(dclone);
use List::Util qw(sum max min first);

ok(defined &main::blessed, 'Scalar::Util blessed promoted into caller');
ok(defined &main::reftype, 'Scalar::Util reftype promoted');
ok(main->can('blessed'), 'can(blessed) after import');
ok(defined &main::dclone, 'Storable dclone promoted');
ok(defined &main::sum, 'List::Util sum promoted');
ok(defined &main::max, 'List::Util max promoted');

# And they still work.
my $obj = bless {}, "Foo";
is(blessed($obj), "Foo", 'blessed() works');
is(reftype($obj), "HASH", 'reftype() works');
is(looks_like_number("3.14"), 1, 'looks_like_number() works') if looks_like_number("3.14");
is(sum(1,2,3,4), 10, 'sum() works');
is(max(3,1,4,1,5), 5, 'max() works');
my $copy = dclone({a => [1,2,3]});
is($copy->{a}[1], 2, 'dclone() works');

# A name NOT imported is not promoted (no over-import of the whole module).
ok(!defined &main::weaken, 'unimported Scalar::Util weaken NOT promoted');

done_testing;
