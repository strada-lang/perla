# Leak: s/// substitution allocates new strings.
for (my $i = 0; $i < 1000; $i++) {
    my $s = "hello world $i";
    $s =~ s/o/O/g;
}
print "ok\n";
