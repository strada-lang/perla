use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: " . $n . "\n"; } }

# Data pipeline
my @tx = (
    {id => 1, amount => 100, type => "credit"},
    {id => 2, amount => 50, type => "debit"},
    {id => 3, amount => 200, type => "credit"},
    {id => 4, amount => 30, type => "debit"},
    {id => 5, amount => 150, type => "credit"},
);
my $total = 0;
for my $t (grep { $_->{type} eq "credit" } @tx) { $total += $t->{amount}; }
ok($total == 450, "pipeline credits");

# Memoization
my %memo;
sub fib_memo {
    my ($n) = @_;
    return $n if $n <= 1;
    if (exists $memo{$n}) { return $memo{$n}; }
    $memo{$n} = fib_memo($n - 1) + fib_memo($n - 2);
    return $memo{$n};
}
ok(fib_memo(10) == 55, "fib memo");
ok(fib_memo(20) == 6765, "fib memo 20");

# Test framework pattern
package Test;
our $run = 0;
our $ok = 0;
sub is { $run++; if ($_[0] eq $_[1]) { $ok++; return 1; } return 0; }
sub summary { return "$ok/$run"; }

package main;
Test::is("hello", "hello", "str");
Test::is(42, 42, "num");
Test::is("x", "x", "x");
ok(Test::summary() eq "3/3", "test framework");

# Table formatter
sub fmt_header {
    my @cols = @_;
    return join(" | ", @cols);
}
ok(fmt_header("Name", "Age", "City") eq "Name | Age | City", "table header");

# Config builder
package Config;
sub new { return bless({data => {}}, $_[0]); }
sub set { $_[0]->{data}{$_[1]} = $_[2]; return $_[0]; }
sub get { return $_[0]->{data}{$_[1]}; }
sub has { return exists $_[0]->{data}{$_[1]}; }
sub keys { return keys %{$_[0]->{data}}; }

package main;
my $cfg = Config->new()->set("host", "localhost")->set("port", "8080")->set("debug", "1");
ok($cfg->get("host") eq "localhost", "config get");
ok($cfg->get("port") eq "8080", "config port");
ok($cfg->has("debug"), "config has");

# Report
print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All data processing tests passed!\n"; }
