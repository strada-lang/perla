use strict;
use warnings;

# Perl's `eval` semantic: $@ is cleared at entry, set to the die message
# on failure, set to "" on success. Regression for two bugs:
#   1. eval STRING wasn't clearing $@ at entry, so a previous eval's $@
#      leaked through and masked the current die.
#   2. Undefined sub calls silently returned undef instead of dying, so
#      `eval "no_such_function()"` never set $@.

# 1. Each eval clears $@ at entry
$@ = "stale";
my $r = eval "1";
die "eval success should clear \$@: got '$@'" unless $@ eq "";

# 2. eval STRING captures runtime die
my $r2 = eval "die 'boom\n'";
die "eval die: got '$@'" unless $@ =~ /^boom/;

# 3. After a die, the NEXT eval clears $@ first then either succeeds or
# fails — no stale leak from the previous eval. Previously broken.
my $r3 = eval "1 + 1";
die "after die, success should clear \$@: got '$@'" unless $@ eq "";

# 4. Undefined sub inside eval STRING sets $@
my $r4 = eval "no_such_function()";
die "undef sub: got '$@'" unless $@ =~ /Undefined subroutine.*no_such_function/;

# 5. Undefined sub outside eval (block scope) dies
my $caught = "";
eval { no_such_other_function(); };
$caught = $@;
die "undef sub in block eval: got '$caught'" unless $caught =~ /Undefined subroutine.*no_such_other_function/;

# 6. Package-qualified undefined sub
my $r6 = eval "Some::Pkg::method()";
die "qualified undef: got '$@'" unless $@ =~ /Undefined subroutine.*Some::Pkg::method/;

print "ok\n";
