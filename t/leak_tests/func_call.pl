# Leak test: function calls with string args
# Expected: no growth — args and return values cleaned up
sub process {
    my ($name, $value) = @_;
    return $name . "=" . $value;
}

for (my $i = 0; $i < 1000; $i++) {
    my $result = process("key", "val_" . $i);
}
print "ok\n";
