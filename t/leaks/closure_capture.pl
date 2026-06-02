# Leak: anon sub capturing outer my-var.
for (my $i = 0; $i < 1000; $i++) {
    my $n = $i;
    my $closure = sub { return $n * 2; };
    my $r = $closure->();
}
print "ok\n";
