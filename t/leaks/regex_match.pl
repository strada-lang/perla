# Leak: regex match in a loop — captures, $1, named groups.
my $text = "alpha 42 bravo";
for (my $i = 0; $i < 1000; $i++) {
    if ($text =~ /(\w+)\s+(\d+)/) {
        my $w = $1; my $n = $2;
    }
}
print "ok\n";
