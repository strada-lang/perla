# Leak test: hash construction in loop
# Expected: no growth — old hash should be freed when reassigned
for (my $i = 0; $i < 1000; $i++) {
    my %h = (name => "test", value => "data", count => $i);
}
print "ok\n";
