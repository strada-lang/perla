# Leak: a . b . c chain — intermediate temps must be cleaned up.
my $base = "hello";
for (my $i = 0; $i < 1000; $i++) {
    my $s = $base . " " . "world " . $i;
}
print "ok\n";
