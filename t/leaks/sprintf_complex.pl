# Leak: sprintf with multiple format specifiers.
for (my $i = 0; $i < 1000; $i++) {
    my $s = sprintf("%-10s %5d %08.3f %x", "iter", $i, $i * 1.5, $i);
}
print "ok\n";
