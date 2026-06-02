use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Chained string ops with method calls ---
package Str;
sub new { return bless({ val => $_[1] }, "Str"); }
sub val { return $_[0]->{val}; }
sub upper { return Str::new("Str", uc($_[0]->{val})); }
sub append {
    my ($self, $other) = @_;
    return Str::new("Str", $self->{val} . $other);
}

package main;

my $s = Str::new("Str", "hello");
ok($s->upper()->val() eq "HELLO", "chained method upper");
ok($s->append(" world")->val() eq "hello world", "chained method append");
ok($s->upper()->append("!")->val() eq "HELLO!", "double chain");

# --- Array ref in boolean context ---
my $empty_ref = [];
my $full_ref = [1, 2, 3];
ok($full_ref, "non-empty arrayref is true");
# Note: empty [] is STRADA_ARRAY (not a ref wrapper), so it's falsy in Perla
# This differs from Perl where [] creates a reference (always true)
ok(!$empty_ref, "empty arrayref is falsy in Perla (no ref wrapper)");

my $empty_href = {};
ok(!$empty_href, "empty hashref is falsy in Perla");

# --- Nested anonymous constructors ---
my $config = {
    db => {
        host => "localhost",
        port => 5432,
        options => {
            timeout => 30,
            retry => 3,
        },
    },
    cache => {
        enabled => 1,
        ttl => 3600,
    },
};
ok($config->{db}->{host} eq "localhost", "3-level nested hash");
ok($config->{db}->{options}->{timeout} == 30, "4-level nested hash");
ok($config->{cache}->{ttl} == 3600, "2-level nested");

# --- Multiple return values ---
sub divmod {
    my ($a, $b) = @_;
    my $quot = int($a / $b);
    my $rem = $a % $b;
    return ($quot, $rem);
}
my ($q, $r) = divmod(17, 5);
ok($q == 3, "divmod quotient");
ok($r == 2, "divmod remainder");

# --- Nested map/grep ---
my @data = (
    { name => "Alice", score => 95 },
    { name => "Bob", score => 60 },
    { name => "Charlie", score => 85 },
);
my @names = map { $_->{name} } grep { $_->{score} >= 80 } @data;
ok(join(",", @names) eq "Alice,Charlie", "nested map/grep");

# --- String multiplication and comparison ---
ok(("a" x 5) eq "aaaaa", "string x 5");
ok(("abc" x 0) eq "", "string x 0");
ok(length("abc" x 100) == 300, "string x 100 length");

# --- Complex conditional ---
my $val = 42;
my $label = ($val > 100) ? "huge"
          : ($val > 50) ? "big"
          : ($val > 20) ? "medium"
          : "small";
ok($label eq "medium", "nested ternary");

# --- For loop with complex step ---
my @evens = ();
for (my $i = 0; $i < 10; $i += 2) {
    push(@evens, $i);
}
ok(join(",", @evens) eq "0,2,4,6,8", "for with += step");

# --- While with complex condition ---
my @collected = ();
my $idx = 0;
my @source = (3, 1, 4, 1, 5, 9, 2, 6);
while ($idx < scalar(@source) && $source[$idx] != 9) {
    push(@collected, $source[$idx]);
    $idx++;
}
ok(join(",", @collected) eq "3,1,4,1,5", "while with && condition");

# --- Unless/else ---
my $found = 0;
unless ($found) {
    $found = 1;
}
ok($found == 1, "unless sets found");

# --- Postfix for ---
my @squared = ();
push(@squared, $_ * $_) for (1..5);
ok(join(",", @squared) eq "1,4,9,16,25", "postfix for with range");

# --- Hash in list context ---
my %scores = ("a" => 10, "b" => 20, "c" => 30);
my @pairs = ();
foreach my $k (sort(keys(%scores))) {
    push(@pairs, $k . "=" . $scores{$k});
}
ok(join(",", @pairs) eq "a=10,b=20,c=30", "hash iteration");

# --- Regex with special chars ---
my $path = "/usr/local/bin/perl";
if ($path =~ /^\/usr\//) {
    ok(1, "regex with escaped slashes");
} else {
    ok(0, "regex with escaped slashes");
}

my $email = 'user@example.com';
if ($email =~ /\w+\@\w+/) {
    ok(1, "regex with @ in pattern");
} else {
    ok(0, "regex with @ in pattern");
}

# --- String with special escapes ---
my $tab_str = "a\tb";
ok(length($tab_str) == 3, "tab in string");
my $newline_str = "a\nb";
ok(length($newline_str) == 3, "newline in string");

# --- Numeric string coercion ---
ok("42" == 42, "string == num");
ok("0" == 0, '"0" == 0');
ok("3.14" > 3, "float string comparison");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All edge case tests passed!\n"; }
