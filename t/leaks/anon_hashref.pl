# Leak: my $ref = {k => v} — fresh hash ref per iter.
for (my $i = 0; $i < 1000; $i++) {
    my $ref = { key => $i, name => "item" };
}
print "ok\n";
