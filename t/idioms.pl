use strict;
use warnings;

# Test common Perl idioms

# --- || for defaults ---
my $name = "";
my $display = $name || "Anonymous";
print "Display: " . $display . "\n";

# --- // (defined-or) ---
my $val = undef;
my $safe = $val // "default";
print "Safe: " . $safe . "\n";

# --- Chained method calls ---
# (test that intermediate results work)
my $data = { items => [10, 20, 30] };
my $first = $data->{items}->[0];
print "First item: " . $first . "\n";

# --- Array in scalar context ---
my @items = (1, 2, 3, 4, 5);
my $count = scalar(@items);
print "Count: " . $count . "\n";

# --- Nested ternary ---
my $x = 15;
my $label = ($x > 20) ? "high" : ($x > 10) ? "medium" : "low";
print "Label: " . $label . "\n";

# --- String equality in conditions ---
my $mode = "debug";
if ($mode eq "debug") {
    print "Debug mode active\n";
}

# --- unless ---
my $ready = 0;
unless ($ready) {
    print "Not ready yet\n";
}

# --- Multiline string concat ---
my $msg = "Hello" .
          " " .
          "World!";
print $msg . "\n";

# --- Nested hash construction ---
my %config = (
    database => {
        host => "localhost",
        port => 5432,
    },
    app => {
        name => "MyApp",
        debug => 1,
    },
);
print "DB host: " . $config{database}->{host} . "\n";
print "App: " . $config{app}->{name} . "\n";

# --- while with last ---
my @nums = (1, 2, 3, 4, 5, 6, 7, 8);
my $sum = 0;
foreach my $n (@nums) {
    last if $n > 5;
    $sum += $n;
}
print "Sum (1-5): " . $sum . "\n";

# --- next to skip ---
my @result = ();
foreach my $n (@nums) {
    next if $n % 2 == 0;
    push(@result, $n);
}
print "Odds: " . join(", ", @result) . "\n";

# --- Nested loops with different vars ---
my @outer = ("a", "b");
my @inner = (1, 2);
foreach my $o (@outer) {
    foreach my $i (@inner) {
        print $o . $i . " ";
    }
}
print "\n";

print "All idiom tests passed!\n";
