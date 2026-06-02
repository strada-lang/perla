#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

package SimpleFH;
sub TIEHANDLE { bless { lines => ["a\n","b\n","c\n"], pos => 0, out => [] }, shift }
sub READLINE { my $s = shift; return undef if $s->{pos} >= @{$s->{lines}}; $s->{lines}[$s->{pos}++] }
sub PRINT { my $s = shift; push @{$s->{out}}, @_ }
sub CLOSE { my $s = shift; $s->{closed} = 1 }
sub get_out { my $s = shift; @{$s->{out}||[]} }
sub is_closed { my $s = shift; !!$s->{closed} }

package main;
tie *FH, 'SimpleFH';

# READLINE
my @lines;
while (my $l = <FH>) { chomp $l; push @lines, $l }
is_deeply(\@lines, ['a','b','c'], 'READLINE returns all lines in sequence then undef');

# PRINT
print FH "hello", "world";
my $obj = tied(*FH);
ok(defined $obj, 'tied(*FH) returns the tied object');
is_deeply([$obj->get_out], ['hello','world'], 'PRINT received the printed args');

# CLOSE
close FH;
ok($obj->is_closed, 'CLOSE was dispatched');

done_testing();
