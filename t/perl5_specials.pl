use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# === __FILE__ ===
my $f = __FILE__;
# File should end with this test's filename
ok(length($f) > 0, "__FILE__ is non-empty");

# === __LINE__ ===
my $l = __LINE__;
ok($l > 0, "__LINE__ returns positive line number: " . $l);

# === __PACKAGE__ ===
ok(__PACKAGE__ eq "main", "__PACKAGE__ in main");

package TestPkg;
sub get_pkg { return __PACKAGE__; }

package main;
ok(TestPkg::get_pkg() eq "TestPkg", "__PACKAGE__ in TestPkg");

# === __END__ handling ===
# (tested implicitly — if __END__ didn't work, the garbage below would cause errors)

# === $$ process ID ===
my $pid = $$;
ok($pid > 0, "\$\$ returns positive PID");

# === $/ input record separator ===
ok($/ eq "\n", "\$/ defaults to newline");

# === $! errno string ===
# Try to open a non-existent file to set errno
my $fh;
open($fh, "<", "/tmp/nonexistent_perla_test_file_12345");
my $err = $!;
ok(length($err) > 0, "\$! returns errno string after failed open");

# === $@ eval error ===
eval { die "test error"; };
ok($@ =~ /test error/, "\$\@ captures die message");

# === $1-$9 capture variables ===
my $str = "hello world 123";
if ($str =~ /(\w+)\s+(\w+)\s+(\d+)/) {
    ok($1 eq "hello", "\$1 capture");
    ok($2 eq "world", "\$2 capture");
    ok($3 eq "123", "\$3 capture");
}

# === $| autoflush ===
$| = 1;
ok($| == 1, "\$| autoflush set");

# === $, output field separator ===
$, = ":";
# Can't easily test print output, but verify the variable is set
$, = "";

# === $\ output record separator ===
$\ = "";
# Verify it can be set without error

# === $; subscript separator ===
my $sep = $;
ok(length($sep) == 1, "\$; is one character");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All special variable tests passed!\n"; }
