use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# === @ARGV and %ENV ===
ok(ref(\@ARGV) eq "ARRAY", "\@ARGV exists");
ok(exists $ENV{PATH}, "\$ENV{PATH} exists");

# === time/localtime ===
my $now = time();
ok($now > 1700000000, "time()");
my @lt = localtime($now);
ok(scalar(@lt) == 9, "localtime 9 elements");
ok($lt[5] >= 124, "localtime year >= 2024");

# === rand/srand ===
srand(12345);
my $r = rand(100);
ok($r >= 0 && $r < 100, "rand in range");

# === String interpolation ===
my $name = "World";
ok("Hello $name" eq "Hello World", "simple interp");

my %h = (k => "val");
ok("got $h{k}" eq "got val", "hash interp");

my @a = (10, 20, 30);
ok("item $a[1]" eq "item 20", "array interp");

my $ref = {x => 42};
ok("x=$ref->{x}" eq "x=42", "hashref interp");

# === File I/O with open(my $fh, ...) ===
my $tmp = "/tmp/perla_comp_test_$$";
open(my $wfh, ">", $tmp);
print $wfh "alpha\nbeta\ngamma\n";
close($wfh);

open(my $rfh, "<", $tmp);
my @lines;
while (my $line = <$rfh>) {
    chomp($line);
    push(@lines, $line);
}
close($rfh);
unlink($tmp);
ok(scalar(@lines) == 3, "file read lines");
ok($lines[0] eq "alpha", "first line");
ok($lines[2] eq "gamma", "last line");

# === Compile-time constants ===
ok(__LINE__ > 0, "__LINE__");
ok(__PACKAGE__ eq "main", "__PACKAGE__");
ok(length(__FILE__) > 0, "__FILE__");

# === Special variables ===
my $pid = $$;
ok($pid > 0, "\$\$");
ok($/ eq "\n", "\$/");
ok(system("true") == 0, "system()");

# === state variables ===
sub counter {
    state $n = 0;
    $n++;
    return $n;
}
ok(counter() == 1, "state 1");
ok(counter() == 2, "state 2");
ok(counter() == 3, "state 3");

# === Postfix until ===
my $i = 0;
$i++ until $i >= 5;
ok($i == 5, "postfix until");

# === Filesystem ===
my $tdir = "/tmp/perla_dir_$$";
mkdir($tdir);
ok(-d $tdir, "mkdir");
rmdir($tdir);
ok(!-d $tdir, "rmdir");

# === OOP with inheritance ===
package Animal;
sub new { return bless({type => $_[1]}, $_[0]); }
sub type { return $_[0]->{type}; }
sub speak { return $_[0]->{type} . " speaks"; }

package Dog;
our @ISA = ('Animal');
sub speak {
    my $base = $_[0]->SUPER::speak();
    return $base . " (woof)";
}

package main;
my $d = Dog->new("dog");
ok($d->type() eq "dog", "inherited method");
ok($d->speak() eq "dog speaks (woof)", "SUPER: " . $d->speak());

# === Class->method() inherited ===
my $d2 = Dog->new("puppy");
ok(ref($d2) eq "Dog", "Class->new inherited");

# === grep with regex ===
my @words = ("apple", "banana", "avocado", "cherry");
my @a_words = grep { /^a/ } @words;
ok(scalar(@a_words) == 2, "grep regex");
ok($a_words[0] eq "apple", "grep result");

# === Complex sort ===
my @nums = (5, 2, 8, 1, 9);
my @sorted = sort { $a <=> $b } @nums;
ok(join(",", @sorted) eq "1,2,5,8,9", "numeric sort");

# === Closures ===
sub make_adder {
    my $n = $_[0];
    return sub { return $_[0] + $n; };
}
my $add5 = make_adder(5);
ok($add5->(10) == 15, "closure");

# === eval/die with ref ===
eval { die {code => 500}; };
ok(ref($@) eq "HASH", "die with hashref");
ok($@->{code} == 500, "die hashref field");

# === sprintf ===
ok(sprintf("%05d", 42) eq "00042", "sprintf pad");
ok(sprintf("%.2f", 3.14159) eq "3.14", "sprintf float");
ok(sprintf("%x", 255) eq "ff", "sprintf hex");

# === oct with prefixes ===
ok(oct("77") == 63, "oct");
ok(oct("0xff") == 255, "oct hex");
ok(oct("0b1010") == 10, "oct binary");

# === Complex data ===
my @records = (
    {name => "Alice", score => 95},
    {name => "Bob", score => 80},
    {name => "Carol", score => 92},
);
my @honor = grep { $_->{score} >= 90 } @records;
my @names = map { $_->{name} } @honor;
ok(join(",", sort @names) eq "Alice,Carol", "filter+map+sort");

# === Method chaining ===
package Builder;
sub new { return bless({parts => []}, $_[0]); }
sub add { push(@{$_[0]->{parts}}, $_[1]); return $_[0]; }
sub build { return join("-", @{$_[0]->{parts}}); }

package main;
my $built = Builder->new()->add("a")->add("b")->add("c")->build();
ok($built eq "a-b-c", "method chain: $built");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All comprehensive tests passed!\n"; }
