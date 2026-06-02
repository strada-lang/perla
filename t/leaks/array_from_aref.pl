# Leak: my @copy = @{$aref} — deref RHS path.
my $aref = [100, 200, 300];
for (my $i = 0; $i < 1000; $i++) {
    my @copy = @{$aref};
}
print "ok\n";
