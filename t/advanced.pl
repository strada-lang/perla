use strict;
use warnings;

# --- Nested hash access ---
my $data = {
    user => {
        name => "Alice",
        age  => 30,
    },
    tags => ["perl", "hacker"],
};
print "Name: " . $data->{user}->{name} . "\n";
print "Tag: " . $data->{tags}->[0] . "\n";

# --- while with assignment ---
my @lines = ("first", "second", "third");
my $idx = 0;
while ($idx < 3) {
    print "Line: " . $lines[$idx] . "\n";
    $idx++;
}

# --- hash iteration ---
my %scores = (alice => 95, bob => 87, charlie => 92);
foreach my $name (sort(keys(%scores))) {
    print $name . ": " . $scores{$name} . "\n";
}

# --- string operations and regex substitution ---
my $str = "Hello, World!";
$str =~ s/World/Perl/;
print "str: " . $str . "\n";

my $text2 = "aaa bbb ccc";
$text2 =~ s/bbb/BBB/;
print "subst: " . $text2 . "\n";

my $nums_str = "1-2-3-4-5";
$nums_str =~ s/-/,/g;
print "global: " . $nums_str . "\n";

# --- wantarray / context ---
my @arr = (5, 3, 1, 4, 2);
my @sorted = sort(@arr);
print "Sorted: " . join(", ", @sorted) . "\n";

# --- reverse ---
my @rev = reverse(@sorted);
print "Reversed: " . join(", ", @rev) . "\n";

# --- exists/delete ---
my %h = (a => 1, b => 2, c => 3);
if (exists($h{b})) {
    print "b exists: " . $h{b} . "\n";
}
delete($h{b});
if (!exists($h{b})) {
    print "b deleted\n";
}

# --- nested function calls ---
sub max_val {
    my ($a, $b) = @_;
    return ($a > $b) ? $a : $b;
}

sub min_val {
    my ($a, $b) = @_;
    return ($a < $b) ? $a : $b;
}

print "max(3,7)=" . max_val(3, 7) . "\n";
print "min(3,7)=" . min_val(3, 7) . "\n";
print "max(min(5,9),max(2,8))=" . max_val(min_val(5, 9), max_val(2, 8)) . "\n";

# --- string repeat ---
my $line = "-" x 20;
print $line . "\n";

# --- multi-line hash construction ---
my %config = (
    host  => "localhost",
    port  => 8080,
    debug => 1,
);
print "Host: " . $config{host} . ":" . $config{port} . "\n";

# --- array push/pop/shift/unshift ---
my @stack = ();
push(@stack, "a");
push(@stack, "b");
push(@stack, "c");
unshift(@stack, "z");
print "Stack: " . join(",", @stack) . "\n";
my $first = shift(@stack);
my $last = pop(@stack);
print "First: " . $first . ", Last: " . $last . "\n";

print "All advanced tests passed!\n";
