# Leak: "${var} text" double-quoted interpolation.
my $name = "world";
for (my $i = 0; $i < 1000; $i++) {
    my $greeting = "hello $name, iter=$i";
}
print "ok\n";
