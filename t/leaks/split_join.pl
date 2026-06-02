# Leak: split + join — list manipulation builtins.
for (my $i = 0; $i < 1000; $i++) {
    my @parts = split /,/, "a,b,c,d,$i";
    my $back = join "|", @parts;
}
print "ok\n";
