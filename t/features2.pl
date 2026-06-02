use strict;
use warnings;

# --- qw() ---
my @colors = qw(red green blue);
print "Colors: " . join(", ", @colors) . "\n";

# --- postfix if/unless ---
my $debug = 1;
print "Debug mode\n" if $debug;
print "Should not print\n" unless $debug;

# --- map ---
my @nums = (1, 2, 3, 4, 5);
my @doubled = map { $_ * 2 } @nums;
print "Doubled: " . join(", ", @doubled) . "\n";

# --- grep ---
my @evens = grep { $_ % 2 == 0 } @nums;
print "Evens: " . join(", ", @evens) . "\n";

# --- uc/lc ---
my $str = "Hello World";
print "Upper: " . uc($str) . "\n";
print "Lower: " . lc($str) . "\n";

# --- index ---
print "Index of 'World': " . index($str, "World") . "\n";

# --- sprintf ---
my $formatted = sprintf("Name: %s, Age: %d", "Alice", 30);
print $formatted . "\n";

# --- regex match ---
my $text = "The quick brown fox";
if ($text =~ /quick/) {
    print "Found 'quick'\n";
}

# --- for C-style ---
for (my $i = 0; $i < 3; $i++) {
    print "i=" . $i . "\n";
}

# --- unless/else ---
my $x = 0;
unless ($x) {
    print "x is falsy\n";
}

# --- chained string ops ---
my $result = "hello" . " " . "world";
print $result . "\n";

print "All features2 tests done!\n";
