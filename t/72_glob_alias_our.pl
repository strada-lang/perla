use strict;
use warnings;

# *Target::name = \$Source::var — read-aliasing must update both the
# stash SCALAR slot AND the registered file-static mirror that `our`
# declarations use, so subsequent unqualified reads of `$name` see
# the aliased source value.

package P;
our $x = "P::x";
our @arr = (1, 2, 3);

package main;
our $x_alias;          # declares main::x_alias + registers mirror
*main::x_alias = \$P::x;
die "read via our: got '$x_alias'" unless $x_alias eq "P::x";

# Mutate source — alias re-fetches.
$P::x = "P::updated";
die "after source mutate: got '$x_alias'" unless $x_alias eq "P::updated";

# Array-slot aliasing (already worked via deref helpers).
our @arr_alias;
*main::arr_alias = \@P::arr;
die "array alias: got '@arr_alias'" unless "@arr_alias" eq "1 2 3";

print "ok\n";
