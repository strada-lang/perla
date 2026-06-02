#!/usr/bin/env perl
use strict;

print "1..8\n";

{
    package H;
    sub TIEHASH { my $c = shift; bless { _data => {} }, $c }
    sub STORE   { $_[0]->{_data}->{$_[1]} = $_[2] }
    sub FETCH   { $_[0]->{_data}->{$_[1]} }
    sub EXISTS  { exists $_[0]->{_data}->{$_[1]} }
    sub DELETE  { delete $_[0]->{_data}->{$_[1]} }
}

my %h;
tie %h, 'H';

$h{a} = 1;
print "$h{a}" == 1 ? "ok 1 - STORE+FETCH a\n" : "not ok 1 (got '$h{a}')\n";

$h{b} = 2;
print "$h{b}" == 2 ? "ok 2 - STORE+FETCH b\n" : "not ok 2 (got '$h{b}')\n";

print (exists $h{a} ? "ok 3 - EXISTS a\n" : "not ok 3\n");
print ((!exists $h{z}) ? "ok 4 - !EXISTS z\n" : "not ok 4\n");

my $tied = tied %h;
print ref($tied) eq 'H' ? "ok 5 - tied returns object\n" : "not ok 5 (got ".ref($tied).")\n";

my $deleted = delete $h{a};
print "$deleted" == 1 ? "ok 6 - delete returns value\n" : "not ok 6 (got '$deleted')\n";
print ((!exists $h{a}) ? "ok 7 - !EXISTS after delete\n" : "not ok 7\n");

untie %h;
print (!defined(tied %h) ? "ok 8 - tied undef after untie\n" : "not ok 8\n");
