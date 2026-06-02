use strict;
use warnings;
use feature 'state';

# Test 1: Per-closure-instance state
sub make_counter {
    return sub {
        state $n = 0;
        return ++$n;
    };
}

my $c1 = make_counter();
my $c2 = make_counter();
die "c1=1" unless $c1->() == 1;
die "c1=2" unless $c1->() == 2;
die "c2=1 (per-instance)" unless $c2->() == 1;
die "c1=3" unless $c1->() == 3;
die "c2=2" unless $c2->() == 2;

# Test 2: Multiple state vars in same closure
sub make_pair {
    return sub {
        state $a = 10;
        state $b = 20;
        $a++; $b += 2;
        return "$a/$b";
    };
}
my $p1 = make_pair();
my $p2 = make_pair();
die "p1 first" unless $p1->() eq "11/22";
die "p1 second" unless $p1->() eq "12/24";
die "p2 first (independent)" unless $p2->() eq "11/22";

# Test 3: State init runs only once per closure
my $init_calls = 0;
sub make_with_init {
    return sub {
        state $val = (++$init_calls);
        return $val;
    };
}
my $w1 = make_with_init();
my $w2 = make_with_init();
$w1->(); $w1->(); $w1->();
die "init once for w1" unless $init_calls == 1;
$w2->();
die "init once for w2 (separate)" unless $init_calls == 2;
$w1->();
die "no re-init" unless $init_calls == 2;

# Test 4: state can hold a hashref
sub make_cache {
    return sub {
        state $cache = {};
        my $k = shift;
        $cache->{$k}++;
        return $cache->{$k};
    };
}
my $ca = make_cache();
my $cb = make_cache();
$ca->("x"); $ca->("x"); $ca->("y");
die "ca x=2" unless $ca->("x") == 3;
die "ca y=1" unless $ca->("y") == 2;
die "cb fresh" unless $cb->("x") == 1;

# Test 5: state in nested closure
sub outer_with_state {
    my $multiplier = shift;
    return sub {
        state $count = 0;
        return ++$count * $multiplier;
    };
}
my $by2 = outer_with_state(2);
my $by5 = outer_with_state(5);
die "by2=2" unless $by2->() == 2;
die "by2=4" unless $by2->() == 4;
die "by5=5" unless $by5->() == 5;

print "ok\n";
