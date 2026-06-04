#!/usr/bin/perl
use warnings; use strict;
use Test::More;
# int type-inference must be SOUND: a `my $x = <int>` is only treated as an
# int (static-int fast path / native int64) when it provably always holds an
# integer. Any write that could make it non-int, or any alias, must disable
# the optimization so output stays correct.

# Eligible cases — must still compute correctly.
{ my $s=0; for(my $i=0;$i<100;$i++){ $s+=$i; } is($s, 4950, 'int loop counter+accumulator'); }
{ my $i=5; my $r = $i<10 ? "lt" : "ge"; is($r, "lt", 'int comparison'); }
{ my $n=7; is($n*$n - 1, 48, 'int arithmetic'); }

# Adversarial: the var becomes (or could become) non-int — output must match perl.
{ my $x=5; $x="foo"; is($x+1, 1, 'reassigned to string'); }
{ my $x=5; $x=3.5; is($x*2, 7, 'reassigned to float'); }
{ my $x=10; $x/=4; is($x, 2.5, 'division makes it a float'); }
{ my $x=5; $x.="z"; is($x, "5z", 'concat .= makes it a string'); }
{ my $x=5; my $r=\$x; $$r="s"; is($x+0, 0, 'written non-int through a ref'); }
{ my $x=123; $x=~s/2/9/; is($x, 193, 's/// mutates in place'); }
# (foreach loop-var alias soundness is verified separately — in a multi-block
#  file it trips an UNRELATED pre-existing perla foreach/block-scoping bug
#  where `for $x (LIST)` stops aliasing a pre-declared my-var; see notes.)
{ my $w=5; while ($w > 0) { $w = 2.5; last; } is($w, 2.5, 'while-loop reassign to float'); }
{ sub _mut { $_[0]="s" } my $x=5; _mut($x); is($x+0, 0, '@_ aliasing write-back'); }
{ my $x=5; my $y; ($x,$y)=("s",9); is("$x$y", "s9", 'list-assignment target'); }
{ my $i=5; { my $i="s"; } is($i+1, 6, 'shadowed name not conflated'); }

done_testing;
