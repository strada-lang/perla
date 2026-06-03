#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# perla supplies a native Carp (the system Carp.pm uses syntax perla can't
# parse). warnings.pm's runtime category functions (enabled/warnif/warn)
# tail-call Carp::short_error_loc via _error_loc to locate the caller frame
# whose ${^WARNING_BITS} to read. That internal helper was missing from
# perla's native Carp, so any runtime warnings:: call died with
#   "Undefined subroutine &Carp::short_error_loc called".
# Moose, DBIx::Class and friends call these at runtime, so this aborted real
# programs mid-init. A native short_error_loc restores the path.

# enabled() on a valid-but-off category returns false (not a crash).
ok(!warnings::enabled('once'),          'warnings::enabled(once) returns false without dying');
ok(!warnings::enabled('uninitialized'), 'warnings::enabled(uninitialized) returns false without dying');

# warnif on an off category is silent and, crucially, does not die — if the
# missing short_error_loc still bit, the script would abort before this point.
warnings::warnif('once', "should stay silent");
ok(1, 'warnings::warnif(once) did not abort the program');

# fatal_enabled likewise consults the caller frame via short_error_loc.
ok(!warnings::fatal_enabled('once'), 'warnings::fatal_enabled(once) returns false without dying');

done_testing;
