# Leak test: method dispatch in loop
# Expected: no growth — dispatch temps should be freed
package Counter;
sub new { return bless { count => 0 }, shift }
sub increment { my ($self) = @_; $self->{count}++; return $self->{count}; }
sub get { return $_[0]->{count}; }

package main;
my $c = Counter->new();
for (my $i = 0; $i < 1000; $i++) {
    $c->increment();
}
print "count: " . $c->get() . "\n";
