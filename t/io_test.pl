use strict;
use warnings;

# Write to a temp file using Strada's core functions
my $tmpfile = "/tmp/perla_io_test.txt";

# Use simple open pattern
my $wfh = open($tmpfile, ">");
print $wfh "line one\n";
print $wfh "line two\n";
print $wfh "line three\n";
close($wfh);

# Read back
my $rfh = open($tmpfile, "<");
my $line1 = readline($rfh);
chomp($line1);
print "Read: " . $line1 . "\n";
close($rfh);

# Clean up
unlink($tmpfile);

print "IO test passed!\n";
