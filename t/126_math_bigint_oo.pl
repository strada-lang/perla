#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native Math::BigInt OO class: ->new, accessor/arith methods (mutate self,
# Math::BigInt semantics), and operator overloading (+ - * ** <=> "" and the
# derived comparisons). Arbitrary precision via the base-10^9 bignum.
use Math::BigInt;

# constructor + stringify
my $x = Math::BigInt->new("123456789012345678901234567890");
is("$x", "123456789012345678901234567890", 'new + "" overload');
is($x->bstr, "123456789012345678901234567890", 'bstr');

# copy is independent; bmul mutates the copy
my $sq = $x->copy->bmul($x);
is("$sq", "15241578753238836750495351562536198787501905199875019052100", 'copy->bmul');
is("$x", "123456789012345678901234567890", 'original unchanged after copy->bmul');

# bpow with a Math::BigInt exponent
my $p = Math::BigInt->new(2);
$p->bpow(Math::BigInt->new(100));
is("$p", "1267650600228229401496703205376", 'bpow mutates self');

# operator overloading (returns new objects)
is(Math::BigInt->new("1000000000000000000000") + Math::BigInt->new(1),
   "1000000000000000000001", 'overloaded +');
is(Math::BigInt->new("99999999999999999999") * 3, "299999999999999999997", 'overloaded * (mixed int)');
is(Math::BigInt->new(5) - Math::BigInt->new(8), "-3", 'overloaded - goes negative');
is(Math::BigInt->new(2) ** 128, "340282366920938463463374607431768211456", 'overloaded **');

# swapped operand (object on the right)
is(10 - Math::BigInt->new(3), "7", 'overloaded - swapped');
is(2 ** Math::BigInt->new(10), "1024", 'overloaded ** swapped');

# comparison overloads (derived from <=>)
ok(Math::BigInt->new("10") ** 20 > Math::BigInt->new("10") ** 19, 'overloaded >');
ok(Math::BigInt->new("42") == Math::BigInt->new(42), 'overloaded ==');
is(Math::BigInt->new(7) <=> Math::BigInt->new(3), 1, 'overloaded <=>');

# division / modulo (bdiv floors; bmod follows divisor sign)
my $bdq = Math::BigInt->new("1000000000000")->bdiv(7);   # scalar context => quotient
is("$bdq", "142857142857", 'bdiv scalar (quotient)');
is(Math::BigInt->new("1000000000000")->bmod(7), "1",            'bmod');
is(Math::BigInt->new("1000000000000") / Math::BigInt->new(7), "142857142857", 'overloaded /');
is(Math::BigInt->new("1000000000000") % Math::BigInt->new(7), "1",            'overloaded %');
is(Math::BigInt->new(-7) / Math::BigInt->new(3), "-3", 'overloaded / floors');
is(Math::BigInt->new(-7) % Math::BigInt->new(3), "2",  'overloaded % divisor sign');
{ my ($q, $r) = Math::BigInt->new(100)->bdiv(7); is("$q/$r", "14/2", 'bdiv list context (quotient, remainder)'); }

# bcmp / bneg / is_zero
is(Math::BigInt->new(3)->bcmp(Math::BigInt->new(9)), -1, 'bcmp');
is(Math::BigInt->new(5)->bneg->bstr, "-5", 'bneg');
ok(Math::BigInt->new(0)->is_zero, 'is_zero true');
ok(!Math::BigInt->new(1)->is_zero, 'is_zero false');

done_testing;
