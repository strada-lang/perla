use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- String functions ---
ok(uc("hello") eq "HELLO", "uc");
ok(lc("HELLO") eq "hello", "lc");
ok(ucfirst("hello") eq "Hello", "ucfirst");
ok(lcfirst("HELLO") eq "hELLO", "lcfirst");
ok(length("hello") == 5, "length");
ok(index("hello world", "world") == 6, "index");
ok(index("hello world", "xyz") == -1, "index not found");
ok(substr("hello", 1, 3) eq "ell", "substr");
ok(substr("hello", -3) eq "llo", "substr negative");
ok(chr(65) eq "A", "chr");
ok(ord("A") == 65, "ord");

# --- Math ---
ok(abs(-5) == 5, "abs neg");
ok(abs(5) == 5, "abs pos");
ok(int(3.9) == 3, "int truncate");
ok(int(-1.5) == -1, "int neg truncate");
ok(hex("ff") == 255, "hex");
ok(oct("10") == 8, "oct");

# --- Array functions ---
my @a = (5, 3, 1, 4, 2);
my @s = sort(@a);
ok(join(",", @s) eq "1,2,3,4,5", "sort");
my @r = reverse(@s);
ok(join(",", @r) eq "5,4,3,2,1", "reverse");
ok($#a == 4, "\$#a");
ok(scalar(@a) == 5, "scalar(@a)");

# --- Hash functions ---
my %h = (a => 1, b => 2, c => 3);
my @k = sort(keys(%h));
ok(join(",", @k) eq "a,b,c", "keys sorted");
ok(exists($h{b}), "exists");
delete($h{b});
ok(!exists($h{b}), "delete");

# --- Regex ---
my $str = "Hello World 42";
ok($str =~ /World/, "regex match");
ok($str !~ /Goodbye/, "regex !~");
if ($str =~ /(\w+)\s+(\w+)\s+(\d+)/) {
    ok($1 eq "Hello", "\$1");
    ok($2 eq "World", "\$2");
    ok($3 eq "42", "\$3");
}

# --- Substitution ---
my $subst_str = "foo bar baz";
$subst_str =~ s/bar/BAR/;
ok($subst_str eq "foo BAR baz", "s///");
$subst_str =~ s/o/O/g;
ok($subst_str eq "fOO BAR baz", "s///g");

# --- qw ---
my @words = qw(alpha beta gamma);
ok(scalar(@words) == 3, "qw count");
ok($words[1] eq "beta", "qw element");

# --- sprintf ---
ok(sprintf("%05d", 42) eq "00042", "sprintf %05d");
ok(sprintf("%.2f", 3.14159) eq "3.14", "sprintf %.2f");
ok(sprintf("%s has %d items", "list", 5) eq "list has 5 items", "sprintf mixed");

# --- Ternary and boolean ---
ok((1 > 0 ? "yes" : "no") eq "yes", "ternary");
ok(("" ? 0 : 1) == 1, "empty string is false");
ok((0 ? 0 : 1) == 1, "0 is false");
ok(("0" ? 0 : 1) == 1, '"0" is false');
ok((1 ? 1 : 0) == 1, "1 is true");
ok((" " ? 1 : 0) == 1, '" " is true');

# --- Defined/undef ---
ok(defined(1), "defined 1");
ok(defined(""), 'defined ""');
ok(!defined(undef), "!defined undef");

# --- Eval/die ---
eval { die "boom"; };
ok($@ =~ /boom/, "\$\@ after die");
eval { 1 + 1; };
ok($@ eq "", "\$\@ empty after success");

# --- do-while ---
my $n = 0;
do { $n++; } while ($n < 10);
ok($n == 10, "do-while");

# --- Postfix modifiers ---
my $x = 0;
$x = 1 if 1;
ok($x == 1, "postfix if");
$x = 2 unless 0;
ok($x == 2, "postfix unless");

# --- Nested data ---
my $data = {
    users => [
        { name => "Alice", age => 30 },
        { name => "Bob", age => 25 },
    ],
};
ok($data->{users}->[0]->{name} eq "Alice", "nested hash->array->hash");
ok($data->{users}->[1]->{age} == 25, "nested access 2");

# --- String x operator ---
ok("abc" x 3 eq "abcabcabc", "x repeat");
ok("-" x 10 eq "----------", "x repeat dash");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All stdlib tests passed!\n"; }
