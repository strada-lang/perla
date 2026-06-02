my $iterations = 100000;
my $result = "";
for (my $i = 0; $i < $iterations; $i++) {
    my $s = "Hello, World! " . $i;
    $s =~ s/World/Perl/;
    $result = $s if $i == $iterations - 1;
}
print "strings: " . $iterations . " iterations, last=" . $result . "\n";
