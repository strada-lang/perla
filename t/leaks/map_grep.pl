# Leak: map and grep allocate intermediate arrays.
for (my $i = 0; $i < 1000; $i++) {
    my @doubled = map { $_ * 2 } (1, 2, 3, 4, 5);
    my @evens = grep { $_ % 2 == 0 } @doubled;
}
print "ok\n";
