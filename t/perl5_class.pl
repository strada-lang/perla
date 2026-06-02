use strict;
use warnings;

my $pass = 0;
my $fail = 0;
sub ok {
    my ($cond, $name) = @_;
    if ($cond) { $pass++; } else { $fail++; print "FAIL: $name\n"; }
}

# Class->method static call syntax
package Counter;
sub new { return bless({ count => 0, name => $_[1] }, "Counter"); }
sub inc { $_[0]->{count}++; return $_[0]; }
sub dec { $_[0]->{count}--; return $_[0]; }
sub value { return $_[0]->{count}; }
sub name { return $_[0]->{name}; }

package main;
my $c = Counter->new("test");
ok(ref($c) eq "Counter", "blessed ref");
ok($c->name() eq "test", "constructor arg");
$c->inc();
$c->inc();
$c->inc();
$c->dec();
ok($c->value() == 2, "method chain value");

# Nested closures / higher-order functions
sub make_adder {
    my ($n) = @_;
    return sub { return $_[0] + $n; };
}
my $add5 = make_adder(5);
my $add10 = make_adder(10);
ok($add5->(3) == 8, "closure add5");
ok($add10->(3) == 13, "closure add10");

# Array ref operations
my $aref = [10, 20, 30];
ok(scalar(@{$aref}) == 3, "array ref size");
ok($aref->[1] == 20, "array ref access");
push @{$aref}, 40;
ok(scalar(@{$aref}) == 4, "push to array ref");

# Hash ref operations
my $href = { name => "Alice", age => 30 };
ok($href->{name} eq "Alice", "hash ref access");
$href->{city} = "NYC";
ok($href->{city} eq "NYC", "hash ref set");

# Nested data structures
my @matrix = ([1, 2, 3], [4, 5, 6], [7, 8, 9]);
ok($matrix[1]->[2] == 6, "nested array");

my @records = (
    { id => 1, tags => ["perl", "code"] },
    { id => 2, tags => ["rust", "fast"] },
);
ok($records[0]->{tags}->[0] eq "perl", "nested array in hash");

# C-style for loop
my $sum = 0;
for (my $i = 1; $i <= 10; $i++) {
    $sum += $i;
}
ok($sum == 55, "c-style for sum");

# eval/die exception handling
my $caught = 0;
eval { die "test error"; };
if ($@) { $caught = 1; }
ok($caught == 1, "eval/die");

# exists with bare syntax in function call
ok(exists $href->{name}, "exists arrow");
delete $href->{age};
ok(!exists($href->{age}), "delete arrow");

print "Passed: $pass\n";
print "Failed: $fail\n";
exit($fail > 0 ? 1 : 0);
