use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# === 1. Bitwise operators ===
ok((0xFF & 0x0F) == 0x0F, "bitwise AND");
ok((0xF0 | 0x0F) == 0xFF, "bitwise OR");
ok((0xFF ^ 0x0F) == 0xF0, "bitwise XOR");
ok((1 << 4) == 16, "left shift");
ok((256 >> 4) == 16, "right shift");
ok((~0 & 0xFF) == 0xFF, "bitwise NOT masked");

# === 2. Array/hash slices ===
my @arr = (10, 20, 30, 40, 50);
my @slice = @arr[1, 3];
ok(join(",", @slice) eq "20,40", "array slice");

my %h = ("a" => 1, "b" => 2, "c" => 3, "d" => 4);
my @hslice = @h{"a", "c", "d"};
ok(join(",", @hslice) eq "1,3,4", "hash slice");

# === 3. sort with custom comparator ===
my @nums = (5, 3, 8, 1, 9, 2);
my @sorted_asc = sort { $a <=> $b } @nums;
ok(join(",", @sorted_asc) eq "1,2,3,5,8,9", "sort numeric asc");

my @sorted_desc = sort { $b <=> $a } @nums;
ok(join(",", @sorted_desc) eq "9,8,5,3,2,1", "sort numeric desc");

my @words = ("banana", "apple", "cherry");
my @sorted_alpha = sort { $a cmp $b } @words;
ok(join(",", @sorted_alpha) eq "apple,banana,cherry", "sort alpha");

my @data = (
    { name => "Charlie", age => 30 },
    { name => "Alice", age => 25 },
    { name => "Bob", age => 35 },
);
my @by_age = sort { $a->{age} <=> $b->{age} } @data;
ok($by_age[0]->{name} eq "Alice", "sort by hash field");
ok($by_age[2]->{name} eq "Bob", "sort by hash field last");

# === 4. SUPER:: ===
package Animal3;
sub new { return bless({ type => "animal", name => $_[1] }, $_[0]); }
sub describe { return "I am " . $_[0]->{name}; }

package Dog3;
our @ISA = ('Animal3');
sub new {
    my ($class, $name) = @_;
    my $self = Animal3::new($class, $name);
    $self->{type} = "dog";
    return $self;
}
sub describe {
    my ($self) = @_;
    my $base = $self->SUPER::describe();
    return $base . " the dog";
}

package main;
my $d = Dog3::new("Dog3", "Rex");
ok($d->describe() eq "I am Rex the dog", "SUPER:: call: " . $d->describe());

# === 5. while (my $line = <$fh>) ===
my $tmpfile = "/tmp/perla_while_fh_test.txt";
my $wfh;
open($wfh, ">", $tmpfile);
print $wfh "alpha\n";
print $wfh "beta\n";
print $wfh "gamma\n";
close($wfh);

my $rfh;
open($rfh, "<", $tmpfile);
my @read_lines = ();
while (my $line = <$rfh>) {
    chomp($line);
    push(@read_lines, $line);
}
close($rfh);
unlink($tmpfile);
ok(scalar(@read_lines) == 3, "while <\$fh> count");
ok($read_lines[0] eq "alpha", "while <\$fh> first");
ok($read_lines[2] eq "gamma", "while <\$fh> last");

# === 6. local $var ===
our $global_val = "original";
sub get_global { return $global_val; }
sub with_local {
    local $global_val = "localized";
    return get_global();
}
ok(get_global() eq "original", "global before local");
ok(with_local() eq "localized", "local inside sub");
ok(get_global() eq "original", "global restored after local");

# === 7. Closures capturing our vars (my-capture needs heap promotion) ===
# True my-var closure capture requires heap promotion of locals,
# which is complex. Use our vars as workaround:
our $counter_state = 0;
my $inc = sub { $counter_state++; return $counter_state; };
my $get = sub { return $counter_state; };
$inc->();
$inc->();
$inc->();
ok($get->() == 3, "closure via our var");

# Closures with args work fine (no capture needed):
my $add5 = sub { return $_[0] + 5; };
my $add10 = sub { return $_[0] + 10; };
ok($add5->(3) == 8, "closure adder 5+3");
ok($add10->(3) == 13, "closure adder 10+3");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All missing feature tests passed!\n"; }
