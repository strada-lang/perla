# Leak: my @copy = @source — borrowed RHS must NOT decref source.
my @src = (10, 20, 30, 40, 50);
for (my $i = 0; $i < 1000; $i++) {
    my @copy = @src;
}
print "ok ", scalar(@src), "\n";
