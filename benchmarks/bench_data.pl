my $iterations = 50000;
my @arr = ();
for (my $i = 0; $i < $iterations; $i++) {
    push(@arr, $i * $i);
}
my $sum = 0;
foreach my $v (@arr) {
    $sum += $v;
}
my %freq = ();
for (my $i = 0; $i < $iterations; $i++) {
    my $key = "key_" . ($i % 100);
    if (exists($freq{$key})) { $freq{$key} += 1; } else { $freq{$key} = 1; }
}
print "data: " . $iterations . " items, sum=" . $sum . ", keys=" . scalar(keys(%freq)) . "\n";
