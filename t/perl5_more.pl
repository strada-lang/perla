use strict;
use warnings;
use constant PI => 3.14159;
use constant MAX_SIZE => 100;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- use constant ---
ok(PI > 3.14, "PI constant");
ok(MAX_SIZE == 100, "MAX_SIZE constant");

# --- Range operator ---
my @range = (1..5);
ok(join(",", @range) eq "1,2,3,4,5", "range 1..5");
ok(scalar(@range) == 5, "range count");

# --- foreach with range ---
my $sum = 0;
foreach my $i (1..10) {
    $sum += $i;
}
ok($sum == 55, "sum 1..10 = 55");

# --- Nested loops ---
my @pairs = ();
foreach my $i (1..3) {
    foreach my $j (1..3) {
        if ($i != $j) {
            push(@pairs, $i . "," . $j);
        }
    }
}
ok(scalar(@pairs) == 6, "nested loop pairs");

# --- Complex data structures ---
my @matrix = ();
foreach my $i (0..2) {
    my @row = ();
    foreach my $j (0..2) {
        push(@row, ($i + 1) * ($j + 1));
    }
    push(@matrix, \@row);
}
ok($matrix[0]->[0] == 1, "matrix[0][0]");
ok($matrix[1]->[1] == 4, "matrix[1][1]");
ok($matrix[2]->[2] == 9, "matrix[2][2]");

# --- String processing pipeline ---
my $csv = "name,age,city\nAlice,30,NYC\nBob,25,LA";
my @rows = split("\n", $csv);
my @header = split(",", $rows[0]);
ok($header[0] eq "name", "csv header");
my @data_rows = ();
foreach my $i (1..$#rows) {
    my @fields = split(",", $rows[$i]);
    my %record = ();
    foreach my $j (0..$#header) {
        $record{$header[$j]} = $fields[$j];
    }
    push(@data_rows, \%record);
}
ok(scalar(@data_rows) == 2, "csv data rows");
ok($data_rows[0]->{name} eq "Alice", "csv first name");
ok($data_rows[1]->{city} eq "LA", "csv last city");

# --- Multiline operations ---
my $text = "The Quick Brown Fox
Jumped Over The
Lazy Dog";
my @words_all = ();
foreach my $line (split("\n", $text)) {
    foreach my $word (split(" ", $line)) {
        push(@words_all, lc($word));
    }
}
ok(scalar(@words_all) == 9, "word count in multiline");
my @sorted_words = sort(@words_all);
ok($sorted_words[0] eq "brown", "first sorted word");

# --- Hash of arrays ---
my %groups = ();
my @items = (
    { name => "a", group => "x" },
    { name => "b", group => "y" },
    { name => "c", group => "x" },
    { name => "d", group => "y" },
    { name => "e", group => "x" },
);
foreach my $item (@items) {
    my $g = $item->{group};
    if (!exists($groups{$g})) {
        $groups{$g} = [];
    }
    push(@{$groups{$g}}, $item->{name});
}
ok(scalar(@{$groups{"x"}}) == 3, "group x has 3");
ok(scalar(@{$groups{"y"}}) == 2, "group y has 2");
ok(join(",", @{$groups{"x"}}) eq "a,c,e", "group x items");

# --- Recursive function ---
sub fibonacci {
    my ($n) = @_;
    if ($n <= 1) { return $n; }
    return fibonacci($n - 1) + fibonacci($n - 2);
}
ok(fibonacci(0) == 0, "fib(0)");
ok(fibonacci(1) == 1, "fib(1)");
ok(fibonacci(10) == 55, "fib(10)");

# --- Closure-like pattern (our var) ---
our $counter_val = 0;
sub increment_counter { $counter_val++; }
sub get_counter { return $counter_val; }
increment_counter();
increment_counter();
increment_counter();
ok(get_counter() == 3, "counter via our");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All perl5_more tests passed!\n"; }
