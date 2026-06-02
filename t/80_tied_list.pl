#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

package CountFetch;
my $fetches = 0;
sub TIESCALAR { my ($c) = @_; bless { val => "init" }, $c }
sub FETCH { my $self = shift; $fetches++; return $self->{val} }
sub STORE { my ($self, $v) = @_; $self->{val} = $v }
sub get_fetches { $fetches }

package main;
tie my $t, 'CountFetch';
$t = "tied-value";

my @arr = ($t, "lit", $t);
is(scalar(@arr), 3, 'list length correct');
is($arr[0], "tied-value", 'tied scalar FETCH at index 0');
is($arr[1], "lit", 'literal at index 1');
is($arr[2], "tied-value", 'tied scalar FETCH at index 2');
cmp_ok(CountFetch::get_fetches(), '>=', 2, 'FETCH fired at least twice during list construction');
done_testing();
