# Leak test: bless + hash construction (OOP pattern)
# Expected: no growth — blessed objects freed when variable reassigned
for (my $i = 0; $i < 1000; $i++) {
    my $obj = bless { id => $i, name => "obj" }, "MyClass";
}
print "ok\n";
