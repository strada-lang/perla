# Leak: sort + keys — list-returning ops.
my %h = (a => 1, b => 2, c => 3, d => 4);
for (my $i = 0; $i < 1000; $i++) {
    my @sorted = sort keys %h;
}
print "ok\n";
