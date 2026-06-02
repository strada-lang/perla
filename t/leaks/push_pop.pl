# Leak: push/pop on a growing array — array mutation paths.
for (my $i = 0; $i < 1000; $i++) {
    my @arr;
    push @arr, "x_$_" for 1..5;
    while (@arr) { pop @arr; }
}
print "ok\n";
