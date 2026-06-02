# Leak: eval BLOCK that catches a die — exception value path.
for (my $i = 0; $i < 1000; $i++) {
    eval { die "oops $i\n"; };
    my $err = $@;  # owns the caught exception string
}
print "ok\n";
