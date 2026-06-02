# Leak test: scalar variable reassignment in loop
# Expected: no growth — old value should be decref'd
for (my $i = 0; $i < 1000; $i++) {
    my $x = "hello world " . $i;
}
print "ok\n";
