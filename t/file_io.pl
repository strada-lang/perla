use strict;
use warnings;

our $pass = 0;
our $fail = 0;

sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

my $tmpfile = "/tmp/perla_fileio_test.txt";

# --- Write with 3-arg open ---
my $wfh;
open($wfh, ">", $tmpfile);
print $wfh "line one\n";
print $wfh "line two\n";
print $wfh "line three\n";
close($wfh);

ok(-e $tmpfile, "file created");

# --- Read with <$fh> diamond operator ---
my $rfh;
open($rfh, "<", $tmpfile);
my $first = <$rfh>;
chomp($first);
ok($first eq "line one", "read first line: " . $first);

my $second = <$rfh>;
chomp($second);
ok($second eq "line two", "read second line");

my $third = <$rfh>;
chomp($third);
ok($third eq "line three", "read third line");
close($rfh);

# --- Read all lines ---
my $rfh2;
open($rfh2, "<", $tmpfile);
my @lines = ();
my $line = <$rfh2>;
while (defined($line)) {
    chomp($line);
    push(@lines, $line);
    $line = <$rfh2>;
}
close($rfh2);
ok(scalar(@lines) == 3, "read all 3 lines");
ok($lines[0] eq "line one", "lines[0]");
ok($lines[2] eq "line three", "lines[2]");

# --- Append mode ---
my $afh;
open($afh, ">>", $tmpfile);
print $afh "line four\n";
close($afh);

my $rfh3;
open($rfh3, "<", $tmpfile);
my @all = ();
my $l = <$rfh3>;
while (defined($l)) {
    chomp($l);
    push(@all, $l);
    $l = <$rfh3>;
}
close($rfh3);
ok(scalar(@all) == 4, "append made 4 lines");
ok($all[3] eq "line four", "appended line");

# --- Clean up ---
unlink($tmpfile);
ok(!-e $tmpfile, "file deleted");

# --- File test operators ---
ok(-d "/tmp", "-d /tmp");
ok(!-f "/tmp", "!-f /tmp (it's a dir)");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All file IO tests passed!\n"; }
