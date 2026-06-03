# Leak test: Hash::Util lock_keys allowed-key storage.
# Expected: lock/unlock cycles and locked hashes dropped at scope exit do not
# leak the allowed-key array attached to hash metadata.
use Hash::Util qw(lock_keys unlock_keys);

for (my $i = 0; $i < 1000; $i++) {
    my %h = (a => 1, b => 2);
    lock_keys(%h, "a", "b", "c", "d");
    unlock_keys(%h);
}

for (my $i = 0; $i < 1000; $i++) {
    my %h = (a => $i);
    lock_keys(%h, "a", "b");
}

my %h = (a => 1);
for (my $i = 0; $i < 1000; $i++) {
    lock_keys(%h, "a", "b");
    lock_keys(%h);
    unlock_keys(%h);
}

print "ok\n";
