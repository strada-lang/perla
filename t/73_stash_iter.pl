use strict;
use warnings;

# `keys %Pkg::` — Perl's stash-as-hash form. Returns the package's
# defined symbol names (sub names + variables).
package Mine;
sub aaa { 1 }
sub bbb { 2 }
our $VAR = 1;
our %HASH = (k=>1);
our @ARR  = (1,2);

package main;

# Direct form
{
    my @syms = sort keys %Mine::;
    my $found = join(",", @syms);
    die "direct keys: got '$found'" unless $found eq "ARR,HASH,VAR,aaa,bbb";
}

# Symbolic-deref form: %{"Pkg::"} (with strict refs off)
{
    no strict 'refs';
    my @syms = sort keys %{"Mine::"};
    my $found = join(",", @syms);
    die "symbolic deref: got '$found'" unless $found eq "ARR,HASH,VAR,aaa,bbb";
}

# each %Pkg:: iterates
{
    my @pairs;
    while (my ($k, $v) = each %Mine::) {
        push @pairs, $k;
    }
    my $found = join(",", sort @pairs);
    die "each: got '$found'" unless $found eq "ARR,HASH,VAR,aaa,bbb";
}

# exists $Pkg::{name}
{
    no strict 'refs';
    die "exists aaa" unless exists $Mine::{aaa};
    die "missing not exists" if exists $Mine::{never_defined};
}

# Symbolic-deref does NOT pollute the stash with phantom empty-name globs
{
    no strict 'refs';
    my @before = keys %Mine::;
    my $junk = %{"Mine::"};      # touch via symbolic deref
    my @after = keys %Mine::;
    die "phantom entry created: before=" . scalar(@before)
        . " after=" . scalar(@after) unless @before == @after;
}

print "ok\n";
