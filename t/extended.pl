use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# 1. die/eval with hashref
eval {
    die { code => 404, message => "Not Found" };
};
ok(ref($@) eq "HASH", "die hashref type");
ok($@->{code} == 404, "die hashref code");
ok($@->{message} eq "Not Found", "die hashref msg");

# 2. die/eval with string
eval { die "boom\n"; };
ok($@ eq "boom\n", "die string");

# 3. Nested eval
eval {
    eval { die "inner"; };
    ok($@ =~ /inner/, "inner caught");
};
ok($@ eq "", "outer clean after nested");

# 4. Matrix access
my @matrix = ([1,2,3], [4,5,6], [7,8,9]);
ok($matrix[1][1] == 5, "matrix center");

# 5. Hash reference manipulation
my $inv = {};
$inv->{apples} = 5;
$inv->{bananas} = 3;
$inv->{apples} += 2;
ok($inv->{apples} == 7, "hash ref +=");
ok(scalar(keys(%{$inv})) == 2, "hash ref keys");

# 6. Grep/map on hashes
my @items = (
    { name => "A", price => 10 },
    { name => "B", price => 25 },
    { name => "C", price => 5 },
    { name => "D", price => 30 },
);
my @expensive = grep { $_->{price} > 15 } @items;
ok(scalar(@expensive) == 2, "grep filter");
my @names = map { $_->{name} } @expensive;
ok(join(",", @names) eq "B,D", "map names");

# 7. Sort by field
my @sorted = sort { $a->{price} <=> $b->{price} } @items;
ok($sorted[0]->{name} eq "C", "sort first");
ok($sorted[3]->{name} eq "D", "sort last");

# 8. String ops
ok(uc("hello") eq "HELLO", "uc");
ok(lc("HELLO") eq "hello", "lc");
ok(ucfirst("hello") eq "Hello", "ucfirst");
ok(substr("Hello, World!", 7, 5) eq "World", "substr");

# 9. Sort + reverse
my @arr = (5, 3, 1, 4, 2);
my @s = sort { $a <=> $b } @arr;
ok(join(",", @s) eq "1,2,3,4,5", "sort numeric");
my @r = reverse(@arr);
ok($r[0] == 2, "reverse");

# 10. Complex data pipeline
my @data = (
    { name => "Alice", scores => [90, 85, 92] },
    { name => "Bob", scores => [78, 88, 95] },
);
sub avg_scores {
    my @vals = @_;
    my $sum = 0;
    foreach my $v (@vals) { $sum += $v; }
    return $sum / scalar(@vals);
}
my @results = ();
foreach my $d (@data) {
    my $a = avg_scores(@{$d->{scores}});
    push(@results, sprintf("%s: %.1f", $d->{name}, $a));
}
ok($results[0] eq "Alice: 89.0", "pipeline: " . $results[0]);
ok($results[1] eq "Bob: 87.0", "pipeline: " . $results[1]);

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All extended tests passed!\n"; }
