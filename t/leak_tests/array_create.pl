# Leak test: array construction in loop
# Expected: no growth — old array should be freed when reassigned
for (my $i = 0; $i < 1000; $i++) {
    my @arr = (1, "two", 3, "four", $i);
}
print "ok\n";
