use strict;
use warnings;

# `my $x` at file scope must preserve a value set by an earlier BEGIN
# block. Perla emits the my-decl init AFTER module-init's BEGIN runs;
# without the "preserve BEGIN value" ternary the unconditional
# `v_x = strada_new_undef()` clobbered the BEGIN's assignment.
# Array/hash had this fix already; scalar was missing it.

my $a;
BEGIN { $a = "set in begin"; }
die "1: scalar got '$a'" unless $a eq "set in begin";

my $b;
BEGIN { $b = wantarray ? "L" : defined(wantarray) ? "S" : "V"; }
die "2: wantarray got '$b'" unless $b eq "V";

my @arr;
BEGIN { @arr = (10, 20, 30); }
die "3: array got @arr" unless "@arr" eq "10 20 30";

my %h;
BEGIN { %h = (k => "v"); }
die "4: hash got " . join(",", %h) unless ($h{k} || "") eq "v";

# Re-declared `my` always resets (Perl semantics).
{
    my $a = "inner";
    die "5: re-decl inner: $a" unless $a eq "inner";
}
die "6: outer preserved: $a" unless $a eq "set in begin";

print "ok\n";
