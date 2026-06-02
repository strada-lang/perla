#!/usr/bin/perl
use warnings;
use Test::More;

# Perl's `randfunc` on Debian/Ubuntu perl 5.38 is `Perl_drand48` —
# libc's drand48 family. perla was using `rand()/RAND_MAX` (a
# different LCG), so `srand(42); rand()` immediately diverged from
# perl. After wiring to `drand48()/srand48()`, identical seed
# produces identical sequence bit-for-bit.

srand(42);
my $a = rand();
my $b = rand();
my $c = rand();

srand(42);
is(sprintf("%.10f", rand()), sprintf("%.10f", $a),
    "srand+rand reproduces the same first value");
is(sprintf("%.10f", rand()), sprintf("%.10f", $b),
    "second value also reproducible");
is(sprintf("%.10f", rand()), sprintf("%.10f", $c),
    "third value also reproducible");

# Specific seed value matches the platform libc drand48.
srand(42);
is(sprintf("%.10f", rand()), "0.7445250001",
    "srand(42); rand() = 0.7445250001 (libc drand48)");
is(sprintf("%.10f", rand()), "0.3427014787",
    "next rand() = 0.3427014787");

# rand(N) scales correctly.
srand(42);
my $r1 = rand(100);
ok($r1 >= 0 && $r1 < 100, "rand(100) is in [0, 100)");
srand(42);
is(sprintf("%.4f", rand(100)), "74.4525",
    "rand(100) = first * 100 (uses same underlying drand48)");

done_testing;
