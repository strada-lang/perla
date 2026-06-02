use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Closures capturing our vars ---
our @captured = ();
my $logger = sub {
    my ($msg) = @_;
    push(@captured, $msg);
};
$logger->("hello");
$logger->("world");
ok(scalar(@captured) == 2, "closure captures our array");
ok($captured[0] eq "hello", "closure capture 1");

# --- Higher-order functions ---
sub make_multiplier {
    my ($factor) = @_;
    # Can't capture $factor (local) yet, use our workaround
    return $factor;  # Return the factor, caller builds the logic
}

# --- Callbacks in data structures ---
our @results = ();
my @transforms = (
    sub { return $_[0] * 2; },
    sub { return $_[0] + 10; },
    sub { return $_[0] * $_[0]; },
);

foreach my $fn (@transforms) {
    push(@results, $fn->(5));
}
ok($results[0] == 10, "callback array: *2");
ok($results[1] == 15, "callback array: +10");
ok($results[2] == 25, "callback array: **2");

# --- Map with anonymous sub ---
my @nums = (1, 2, 3, 4, 5);
my $doubler = sub { return $_[0] * 2; };
my @doubled = ();
foreach my $n (@nums) {
    push(@doubled, $doubler->($n));
}
ok(join(",", @doubled) eq "2,4,6,8,10", "callback via foreach");

# --- Sort with comparison sub ---
# (Using manual sort since sort with custom comparator isn't supported yet)
my @data = (
    { name => "Charlie", score => 85 },
    { name => "Alice", score => 95 },
    { name => "Bob", score => 90 },
);
# Manual insertion sort by score
my @sorted_data = ();
foreach my $item (@data) {
    my $inserted = 0;
    my @new_sorted = ();
    foreach my $existing (@sorted_data) {
        if (!$inserted && $item->{score} > $existing->{score}) {
            push(@new_sorted, $item);
            $inserted = 1;
        }
        push(@new_sorted, $existing);
    }
    if (!$inserted) { push(@new_sorted, $item); }
    @sorted_data = @new_sorted;
}
ok($sorted_data[0]->{name} eq "Alice", "sorted first");
ok($sorted_data[1]->{name} eq "Bob", "sorted second");
ok($sorted_data[2]->{name} eq "Charlie", "sorted third");

# --- Pipeline pattern ---
sub pipeline {
    my ($value, @fns) = @_;
    foreach my $fn (@fns) {
        $value = $fn->($value);
    }
    return $value;
}

my $result = pipeline(
    "  Hello, World!  ",
    sub { my $s = $_[0]; $s =~ s/^\s+//; return $s; },
    sub { my $s = $_[0]; $s =~ s/\s+$//; return $s; },
    sub { return uc($_[0]); },
);
ok($result eq "HELLO, WORLD!", "pipeline: " . $result);

# --- Event handler registry ---
package Registry;
sub new { return bless({ handlers => {} }, "Registry"); }
sub register {
    my ($self, $name, $fn) = @_;
    $self->{handlers}{$name} = $fn;
}
sub call {
    my ($self, $name, $arg) = @_;
    if (exists($self->{handlers}{$name})) {
        return $self->{handlers}{$name}->($arg);
    }
    return undef;
}
sub has_handler {
    my ($self, $name) = @_;
    return exists($self->{handlers}{$name});
}

package main;

my $reg = Registry::new("Registry");
$reg->register("double", sub { return $_[0] * 2; });
$reg->register("greet", sub { return "Hello, " . $_[0] . "!"; });
$reg->register("upper", sub { return uc($_[0]); });

ok($reg->call("double", 21) == 42, "registry double");
ok($reg->call("greet", "Perl") eq "Hello, Perl!", "registry greet");
ok($reg->call("upper", "hello") eq "HELLO", "registry upper");
ok($reg->has_handler("double"), "registry has double");
ok(!$reg->has_handler("missing"), "registry !has missing");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All closure tests passed!\n"; }
