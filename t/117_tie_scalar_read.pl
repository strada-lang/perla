#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Tied scalars must dispatch FETCH on read and STORE on write. Reads through
# string/numeric coercion (interpolation, comparison, my-init) already
# dispatched; the gaps were the direct print/say path and sprintf %s, which
# printed the underlying placeholder instead of the FETCH result.

{
    package Counter;
    sub TIESCALAR { my $c = 0; bless \$c, shift }
    sub FETCH { my $s = shift; $$s++ }          # post-incrementing FETCH
    sub STORE { my ($s, $v) = @_; $$s = $v }
}

tie my $x, "Counter";
# Concatenation dispatches FETCH each time (post-increment: 0,1,2).
my $out = "";
$out .= $x for 1 .. 3;
is($out, "012", 'concat of tied scalar dispatches FETCH each read');

# STORE then FETCH (captured into a plain var first).
$x = 100;
my $after = $x;
is($after, 100, 'STORE then FETCH round-trips');

{
    package Doubler;
    sub TIESCALAR { bless \(my $n = 0), shift }
    sub FETCH { ${ $_[0] } }
    sub STORE { ${ $_[0] } = $_[1] * 2 }        # STORE doubles
}

tie my $d, "Doubler";
$d = 21;
my $dv = $d;
is($dv, 42, 'STORE transforms the stored value (x2)');

{
    package Fixed;
    sub TIESCALAR { bless \(my $n = 99), shift }
    sub FETCH { ${ $_[0] } }
    sub STORE { ${ $_[0] } = $_[1] }
}
tie my $f, "Fixed";

# Direct print path (was broken — printed empty).
my $printed;
{
    open my $fh, ">", \$printed or die;
    my $save = select($fh);
    print $f;
    select($save);
}
is($printed, "99", 'print of tied scalar dispatches FETCH');

# sprintf %s (was broken — bypassed FETCH).
is(sprintf("[%s]", $f), "[99]", 'sprintf %s of tied scalar dispatches FETCH');

# Numeric context.
my $n = $f + 1;
is($n, 100, 'tied scalar in numeric context');

# Interpolation.
my $istr = "v=$f";
is($istr, "v=99", 'tied scalar interpolation');

# tied() returns the underlying object.
my $obj = tied $f;
ok(defined($obj) && ref($obj) eq "Fixed", 'tied() returns the tie object');

done_testing;
