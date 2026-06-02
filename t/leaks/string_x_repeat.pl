# Leak: x repeat allocates fresh strings.
for (my $i = 0; $i < 1000; $i++) {
    my $s = "ab" x 10;
}
print "ok\n";
