use strict;
use warnings;

our $pass = 0;
our $fail = 0;

sub ok {
    my ($test, $name) = @_;
    if ($test) {
        $pass++;
    } else {
        $fail++;
        print "FAIL: " . $name . "\n";
    }
}

# --- Regex captures ---
my $str = "Hello World 2024";
if ($str =~ /(\w+)\s+(\w+)\s+(\d+)/) {
    ok($1 eq "Hello", "capture \$1");
    ok($2 eq "World", "capture \$2");
    ok($3 eq "2024", "capture \$3");
} else {
    ok(0, "regex match with captures");
}

# --- $#array ---
my @arr = (10, 20, 30, 40, 50);
ok($#arr == 4, "\$#arr == 4");

# --- abs/int/hex/oct ---
ok(abs(-42) == 42, "abs(-42)");
ok(abs(3.14) > 3.13, "abs(3.14)");
ok(int(3.7) == 3, "int(3.7)");
ok(int(-2.9) == -2, "int(-2.9)");
ok(hex("ff") == 255, "hex('ff')");
ok(hex("0x1a") == 26, "hex('0x1a')");
ok(oct("77") == 63, "oct('77')");

# --- tr/y ---
my $text = "Hello";
$text =~ tr/Helo/WXYZ/;
ok($text eq "WXYYZ", "tr/Helo/WXYZ/ => " . $text);

my $vowels = "Hello World";
$vowels =~ tr/aeiou/*/;
ok(index($vowels, "H") >= 0, "tr preserves H");

# --- Negative indices ---
ok($arr[-1] == 50, "arr[-1]");
ok($arr[-2] == 40, "arr[-2]");

# --- String repeat ---
ok("ab" x 3 eq "ababab", "string x repeat");

# --- Defined-or ---
my $undef_val = undef;
ok(($undef_val // "default") eq "default", "// with undef");
ok((42 // "default") == 42, "// with defined");

# --- Ternary ---
ok((1 ? "yes" : "no") eq "yes", "ternary true");
ok((0 ? "yes" : "no") eq "no", "ternary false");

# --- Boolean context ---
ok(!0, "!0 is true");
ok(!"", '!"" is true');
ok(!undef, "!undef is true");
ok(1, "1 is true");
ok("x", '"x" is true');

# --- String comparison ---
ok("abc" lt "abd", "lt");
ok("abd" gt "abc", "gt");
ok("abc" le "abc", "le");
ok("abc" ge "abc", "ge");

# --- Numeric context for strings ---
ok("10" + 5 == 15, "string + num");
ok("3.14" + 0 > 3.13, "float string + 0");

# --- exists on nested ---
my %h = (a => { b => 1 });
ok(exists($h{a}), "exists top level");

# --- delete ---
my %d = (x => 1, y => 2, z => 3);
delete($d{y});
ok(!exists($d{y}), "delete removes key");
ok(exists($d{x}), "delete preserves others");

# --- substr with negative ---
my $s = "Hello World";
ok(substr($s, -5) eq "World", "substr negative offset");
ok(substr($s, 0, 5) eq "Hello", "substr with length");

# --- index with offset (not implemented yet, skip) ---

# --- join/split ---
ok(join("-", qw(a b c)) eq "a-b-c", "join qw");
my @parts = split(",", "1,2,3");
ok(scalar(@parts) == 3, "split count");
ok($parts[0] eq "1", "split first");

# --- push/pop/shift/unshift ---
my @stack = ();
push(@stack, 1);
push(@stack, 2);
push(@stack, 3);
ok(pop(@stack) == 3, "pop");
ok(shift(@stack) == 1, "shift");
unshift(@stack, 0);
ok($stack[0] == 0, "unshift");

# --- sort ---
my @sorted = sort(qw(banana apple cherry));
ok($sorted[0] eq "apple", "sort first");
ok($sorted[2] eq "cherry", "sort last");

# --- reverse ---
my @rev = reverse(qw(a b c));
ok(join("", @rev) eq "cba", "reverse array");

# --- map/grep ---
my @doubled = map { $_ * 2 } (1, 2, 3);
ok(join(",", @doubled) eq "2,4,6", "map");
my @odds = grep { $_ % 2 == 1 } (1, 2, 3, 4, 5);
ok(join(",", @odds) eq "1,3,5", "grep");

# --- eval/die ---
eval { die "test error"; };
ok(length($@) > 0, "eval catches die");

# --- sprintf ---
ok(sprintf("%d", 42) eq "42", "sprintf %d");
ok(sprintf("%s=%d", "x", 10) eq "x=10", "sprintf %s=%d");

# --- do-while ---
my $dw = 0;
do { $dw++; } while ($dw < 3);
ok($dw == 3, "do-while");

# Report
print "\n";
print "Passed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) {
    print "All perl5 feature tests passed!\n";
}
