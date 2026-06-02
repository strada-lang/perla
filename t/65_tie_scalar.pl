#!/usr/bin/env perl
use strict;

print "1..6\n";

# --- 1) Counter: FETCH/STORE that mutates state ---
{
    package Counter;
    sub TIESCALAR {
        my $class = shift;
        my $val = shift // 0;
        return bless \my $self, $class;
    }
    sub FETCH {
        my $self = shift;
        return ++$$self;
    }
    sub STORE {
        my ($self, $val) = @_;
        $$self = $val;
    }
}
my $count;
tie $count, 'Counter';
print "$count" == 1 ? "ok 1 - first FETCH returns 1\n" : "not ok 1 (got '$count')\n";
print "$count" == 2 ? "ok 2 - second FETCH returns 2\n" : "not ok 2 (got '$count')\n";
$count = 100;
print "$count" == 101 ? "ok 3 - STORE then FETCH returns 101\n" : "not ok 3 (got '$count')\n";

# --- 2) Echo: just stores and returns the value (basic round-trip) ---
{
    package Echo;
    sub TIESCALAR { my $c = shift; my $v; bless \$v, $c }
    sub FETCH { my $s = shift; return $$s }
    sub STORE { my ($s, $v) = @_; $$s = $v }
}
my $val;
tie $val, 'Echo';
$val = "hello";
print "$val" eq "hello" ? "ok 4 - string round-trip\n" : "not ok 4 (got '$val')\n";
$val = 42;
print "$val" == 42 ? "ok 5 - numeric round-trip\n" : "not ok 5 (got '$val')\n";

# --- 3) STORE returns a transformed view (FETCH returns uppercased) ---
{
    package Upper;
    sub TIESCALAR { my $c = shift; my $v = ""; bless \$v, $c }
    sub FETCH { my $s = shift; return uc($$s) }
    sub STORE { my ($s, $v) = @_; $$s = $v }
}
my $u;
tie $u, 'Upper';
$u = "hello world";
print "$u" eq "HELLO WORLD" ? "ok 6 - FETCH transforms\n" : "not ok 6 (got '$u')\n";
