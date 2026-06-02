# Leak test: hash ref construction in loop
# Expected: no growth — old ref should be freed when variable reassigned
for (my $i = 0; $i < 1000; $i++) {
    my $ref = { name => "test", id => $i, tags => [1, 2, 3] };
}
print "ok\n";
