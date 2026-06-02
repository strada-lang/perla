use strict;
use warnings;

# Build a simple test framework, then use it to test itself

package TestSuite;

sub new {
    my ($class, %args) = @_;
    return bless({
        name     => $args{name} || "unnamed",
        tests    => [],
        passed   => 0,
        failed   => 0,
        skipped  => 0,
    }, $class);
}

sub ok {
    my ($self, $test, $name) = @_;
    my %result = (name => $name, passed => 0);
    if ($test) {
        $result{passed} = 1;
        $self->{passed}++;
    } else {
        $self->{failed}++;
        print "  not ok - " . $name . "\n";
    }
    push(@{$self->{tests}}, \%result);
}

sub is {
    my ($self, $got, $expected, $name) = @_;
    if ($got eq $expected) {
        $self->ok(1, $name);
    } else {
        $self->ok(0, $name . " (got '" . $got . "', expected '" . $expected . "')");
    }
}

sub is_num {
    my ($self, $got, $expected, $name) = @_;
    if ($got == $expected) {
        $self->ok(1, $name);
    } else {
        $self->ok(0, $name . " (got " . $got . ", expected " . $expected . ")");
    }
}

sub skip {
    my ($self, $name, $reason) = @_;
    $self->{skipped}++;
    push(@{$self->{tests}}, { name => $name, passed => 1, skipped => 1 });
}

sub total  { return scalar(@{$_[0]->{tests}}); }
sub passed { return $_[0]->{passed}; }
sub failed { return $_[0]->{failed}; }

sub report {
    my ($self) = @_;
    my $total = $self->total();
    print "\n" . $self->{name} . ": ";
    print $self->{passed} . "/" . $total . " passed";
    if ($self->{failed} > 0) { print ", " . $self->{failed} . " failed"; }
    if ($self->{skipped} > 0) { print ", " . $self->{skipped} . " skipped"; }
    print "\n";
    return $self->{failed} == 0;
}

package main;

# Now use the framework to test various things

my $t = TestSuite::new("TestSuite", name => "Self-Test");

# Test the framework itself
$t->ok(1, "basic ok true");
$t->ok(!0, "basic ok negation");

$t->is("hello", "hello", "is string equal");
$t->is_num(42, 42, "is_num equal");
$t->is_num(2 + 3, 5, "is_num arithmetic");

# Test string operations
$t->is(uc("hello"), "HELLO", "uc");
$t->is(lc("WORLD"), "world", "lc");
$t->is(length("hello"), 5, "length");
$t->is(substr("hello world", 6, 5), "world", "substr");
$t->is(join(",", "a", "b", "c"), "a,b,c", "join");

# Test array operations
my @arr = (1, 2, 3, 4, 5);
$t->is_num(scalar(@arr), 5, "array length");
$t->is_num($arr[0], 1, "array first");
$t->is_num($arr[4], 5, "array last");

push(@arr, 6);
$t->is_num(scalar(@arr), 6, "after push");

my $popped = pop(@arr);
$t->is_num($popped, 6, "pop value");

# Test hash operations
my %h = (a => 1, b => 2, c => 3);
$t->is_num($h{a}, 1, "hash access");
$t->ok(exists($h{b}), "hash exists");
$t->ok(!exists($h{z}), "hash not exists");
$t->is_num(scalar(keys(%h)), 3, "hash keys count");

# Test regex
$t->ok("hello world" =~ /world/, "regex match");
$t->ok(!("hello" =~ /xyz/), "regex no match");

my $s = "Hello, World!";
$s =~ s/World/Perl/;
$t->is($s, "Hello, Perl!", "regex replace");

# Test control flow
my $x = 10;
my $result = ($x > 5) ? "big" : "small";
$t->is($result, "big", "ternary");

# Test references
my $href = { x => 10, y => 20 };
$t->is_num($href->{x}, 10, "hashref access");
$t->is(ref($href), "HASH", "ref type hash");

my $aref = [1, 2, 3];
$t->is_num($aref->[1], 2, "arrayref access");
$t->is(ref($aref), "ARRAY", "ref type array");

# Test skip
$t->skip("skipped test", "just testing skip");

$t->report();

# Meta-test: verify the framework worked
our $pass2 = 0;
our $fail2 = 0;
sub ok2 { my ($test, $name) = @_; if ($test) { $pass2++; } else { $fail2++; print "META FAIL: $name\n"; } }

ok2($t->total() == 28, "total tests: " . $t->total());
ok2($t->passed() == 27, "passed: " . $t->passed());
ok2($t->failed() == 0, "failed: " . $t->failed());

print "\nMeta: " . $pass2 . "/" . ($pass2 + $fail2) . " passed\n";
if ($fail2 == 0 && $t->failed() == 0) { print "All framework tests passed!\n"; }
