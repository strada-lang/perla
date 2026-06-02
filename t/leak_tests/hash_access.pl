# Leak test: repeated hash access
# Expected: no growth — hash fetch returns owned ref, must be freed by caller
my %data = (name => "Alice", age => "30", city => "NYC");
for (my $i = 0; $i < 1000; $i++) {
    my $n = $data{name};
    my $a = $data{age};
    my $c = $data{city};
}
print "ok\n";
