# Leak test: tied scalars (FETCH/STORE in a loop)
# Exercises perla_tie_scalar, strada_tied_scalar_fetch via to_X dispatch,
# the write-side STORE dispatch in codegen, and strada_tied_scalar_store.
# Each iteration FETCHes (incrementing the counter) and STOREs.

package Counter;
sub TIESCALAR {
    my $class = shift;
    my $val = 0;
    return bless \$val, $class;
}
sub FETCH {
    my $self = shift;
    return ++$$self;
}
sub STORE {
    my ($self, $val) = @_;
    $$self = $val;
}

package main;

my $count;
tie $count, 'Counter';

# 1000 FETCH/STORE round-trips through the tied scalar
my $sum = 0;
for (my $i = 0; $i < 1000; $i++) {
    $sum += $count;        # FETCH
    $count = $i * 2;       # STORE
}

print "ok\n";
