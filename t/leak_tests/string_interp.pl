# Leak test: string interpolation in loop
# Expected: no growth — interpolated strings freed when variable reassigned
my $name = "world";
for (my $i = 0; $i < 1000; $i++) {
    my $s = "hello $name number $i";
}
print "ok\n";
