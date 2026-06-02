#!/usr/bin/perl
use warnings;
use Test::More;

# Compound (multi-key) hash subscript in string interpolation:
# `"$h{$a, $b}"` is the $;-joined key `$h{join($;, $a, $b)}`, same as
# the non-interp parser builds. Previously the interp scanner stringified
# `$a,$b` as a bare list (no separator), so the fetch key never matched
# the stored key. A quoted first piece (`'x','y'`) was even mis-read as
# a single single-quoted key.

my %h;

$h{1,2,3} = "numeric";
is("$h{1,2,3}", "numeric", "numeric literal compound key in interp");

my ($a, $b) = ("alpha", "beta");
$h{$a, $b} = "vars";
is("$h{$a,$b}", "vars", "scalar-var compound key in interp");

$h{'x','y'} = "sq";
is("$h{'x','y'}", "sq", "single-quoted compound key in interp");

$h{"p","q"} = "dq";
is("$h{\"p\",\"q\"}", "dq", "double-quoted compound key in interp");

$h{$a, 2, $b} = "mixed";
is("$h{$a,2,$b}", "mixed", "mixed var/literal compound key in interp");

# The stored key really is $;-joined (\034 separator) — confirm a
# single-element lookup with the joined string also hits.
my $joined = join($;, "alpha", "beta");
is($h{$joined}, "vars", "compound key equals \$;-joined single key");

# Interp and non-interp agree.
is("$h{1,2,3}", $h{1,2,3}, "interp matches non-interp for same compound key");

done_testing;
