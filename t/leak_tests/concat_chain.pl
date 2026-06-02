# Leak test: string concatenation chain
# Expected: no growth — intermediate concat results should be freed
for (my $i = 0; $i < 1000; $i++) {
    my $s = "a" . "b" . "c" . "d" . "e";
}
print "ok\n";
