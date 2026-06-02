#!/usr/bin/perl
use warnings;
use Test::More;

# Sub-local `my` in a format inside a sub. Each call to the sub
# captures its own snapshot of the lexicals at write time.

sub render {
    my ($name, $score) = @_;
    open(OUT, ">>", "/tmp/perla_t84.out") or die;
    format OUT =
@<<<<<<<<< @####
$name, $score
.
    write OUT;
    close OUT;
}

unlink "/tmp/perla_t84.out";
render("Alice", 95);
render("Bob",   42);
render("Carol", 100);

open(my $in, "<", "/tmp/perla_t84.out") or die;
my $got = do { local $/; <$in> };
close $in;
unlink "/tmp/perla_t84.out";

like($got, qr/Alice\s+95/,  'first render — sub-local \$name + \$score visible');
like($got, qr/Bob\s+42/,    'second render — fresh lexicals captured per call');
like($got, qr/Carol\s+100/, 'third render — lexicals re-read on each write');

done_testing();
