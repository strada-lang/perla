use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# C-style for with next/last
my @evens = ();
for (my $i = 0; $i < 20; $i++) {
    next if $i % 2 != 0;
    last if $i > 10;
    push(@evens, $i);
}
ok(join(",", @evens) eq "0,2,4,6,8,10", "for/next/last");

# Nested deref avg
my @students = (
    { name => "Alice", grades => [90, 85, 92] },
    { name => "Bob", grades => [78, 88, 95] },
);
sub avg { my $sum = 0; foreach my $v (@_) { $sum += $v; } return int($sum / scalar(@_)); }
ok(avg(@{$students[0]->{grades}}) == 89, "nested deref avg");

# Word frequency with regex split
my %wc = ();
my @ws = split(/\s+/, "the cat the dog the cat");
foreach my $w (@ws) {
    if (exists($wc{$w})) { $wc{$w} += 1; } else { $wc{$w} = 1; }
}
ok($wc{the} == 3, "word count: the");
ok($wc{cat} == 2, "word count: cat");

# Sprintf
my $line = sprintf("%05d %-8s %6.2f", 42, "test", 3.14);
ok($line eq "00042 test       3.14", "sprintf");

print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All advanced2 tests passed!\n"; }
