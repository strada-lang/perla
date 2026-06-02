# Leak: my @arr = (LITERAL LIST) — fresh anon list each iter.
# Regression for: array_create leak (fixed in commit 317fe13).
for (my $i = 0; $i < 1000; $i++) {
    my @arr = (1, "two", 3, "four", $i);
}
print "ok\n";
