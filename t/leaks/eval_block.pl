# Leak: eval BLOCK — exception machinery + try/catch.
for (my $i = 0; $i < 1000; $i++) {
    eval {
        my $x = 1 / ($i + 1);
        die "boom\n" if $i == -1;  # never fires
    };
    my $err = $@;
}
print "ok\n";
