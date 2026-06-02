#!/usr/bin/perl
use warnings;
use Test::More;

format ALPHA =
A: @<<<<
$_
.

format BETA =
B: @<<<<
$_
.

open(FA, ">", "/tmp/perla_t82_a.out") or die;
open(FB, ">", "/tmp/perla_t82_b.out") or die;

# Set per-handle $~ for FA and FB via select-then-assign
select(FA); $~ = "ALPHA";
select(FB); $~ = "BETA";
select(STDOUT);

# Write to each; per-handle slot dictates format selection
$_ = "one"; write FA;
$_ = "two"; write FB;

close FA; close FB;

open(my $in_a, "<", "/tmp/perla_t82_a.out") or die;
my $got_a = do { local $/; <$in_a> };
close $in_a;
unlink "/tmp/perla_t82_a.out";

open(my $in_b, "<", "/tmp/perla_t82_b.out") or die;
my $got_b = do { local $/; <$in_b> };
close $in_b;
unlink "/tmp/perla_t82_b.out";

like($got_a, qr/A: one/, 'FA used its per-handle \$~ = ALPHA');
like($got_b, qr/B: two/, 'FB used its per-handle \$~ = BETA');

done_testing();
