package Counter;
sub new { return bless({ count => 0 }, $_[0]); }
sub increment { $_[0]->{count}++; }
sub get { return $_[0]->{count}; }

package main;
my $iterations = 200000;
my $c = Counter::new("Counter");
for (my $i = 0; $i < $iterations; $i++) {
    $c->increment();
}
print "oop: " . $iterations . " method calls, count=" . $c->get() . "\n";
