# Leak: my $ref = [1, 2, 3] — fresh array ref per iter.
for (my $i = 0; $i < 1000; $i++) {
    my $ref = [1, 2, 3, "four", $i];
}
print "ok\n";
