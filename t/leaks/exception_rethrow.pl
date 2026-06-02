# Leak: nested eval with rethrow — error path stress.
for (my $i = 0; $i < 1000; $i++) {
    eval {
        eval { die { code => 42, msg => "inner" }; };
        die $@ if $@;
    };
    my $err = $@;
}
print "ok\n";
