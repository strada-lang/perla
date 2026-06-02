#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# format/write value lines: bridge `our`/package vars (which diverge from
# their stash slot after reassignment) and support string/number literals.
# Previously only `my` lexicals rendered; our-vars and literals came out
# blank. Write to a named handle on a temp file and read it back.

my $tmp = "/tmp/perla_fmt_$$.txt";
sub slurp { open my $fh, "<", $tmp or return ""; local $/; my $c = <$fh>; close $fh; unlink $tmp; return $c; }

# --- our-vars reassigned in a loop (the classic report idiom) ---
our ($prod, $qty);
format OUT1 =
@<<<<<<<<<< @>>>
$prod, $qty
.
open(OUT1, ">", $tmp) or die;
for my $r (["Widget", 5], ["Gadget", 12]) { ($prod, $qty) = @$r; write OUT1; }
close OUT1;
is(slurp(), "Widget         5\nGadget        12\n", "our-vars reassigned in loop render");

# --- string + number literals in the value line ---
format OUT2 =
@<<<<<< @>>>
"Label:", 99
.
open(OUT2, ">", $tmp) or die;
write OUT2;
close OUT2;
is(slurp(), "Label:    99\n", "string + number literals render");

# --- mix: our var + literal + my var ---
our $city;
my $code = "X1";
format OUT3 =
@<<<<<<<< @<<< @<<<
$city, "tag", $code
.
$city = "Rome";
open(OUT3, ">", $tmp) or die;
write OUT3;
close OUT3;
is(slurp(), "Rome      tag  X1\n", "our + literal + my mixed");

done_testing;
