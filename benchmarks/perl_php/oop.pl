package Counter;
sub new { return bless({count=>0}, $_[0]); }
sub increment { $_[0]->{count}++; }
sub get { return $_[0]->{count}; }
package main;
my $it=5000000; my $c=Counter::new("Counter");
for (my $i=0;$i<$it;$i++){ $c->increment(); }
print "oop: $it method calls, count=".$c->get()."\n";
