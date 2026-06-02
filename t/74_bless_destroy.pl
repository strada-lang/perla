use strict;
use warnings;

# Regression: `bless { ... }, "Pkg"` at scope exit must not
# double-free the package name. perla_bless interns the name as
# stash->name (externally owned by PerlStash) which strada_free_value
# would otherwise pass to strada_intern_release → free(), corrupting
# every subsequent bless in the same package. The fix sets
# blessed_immortal=1 so the release is skipped.

{
    my $obj = bless { name => "Rex" }, "Dog";
}  # scope exit triggers DESTROY + free

# Re-bless into same package — would crash with the stash name freed.
{
    my $obj2 = bless { name => "Max" }, "Dog";
}

# Many objects of same class, mixed with other allocs.
for (1..50) {
    my $a = bless { id => $_ }, "Counter";
    my $b = bless { id => $_ * 2 }, "Counter";
    my $h = { x => $_, y => $_ + 1 };
}

# Multiple distinct packages.
for (1..20) {
    my $a = bless [], "A$_";
    my $b = bless [], "B$_";
}

print "ok\n";
