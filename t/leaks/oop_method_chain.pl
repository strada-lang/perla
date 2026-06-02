# Leak: OOP method chain — bless + multiple method calls.
package Counter;
sub new { my $c = shift; bless { n => 0 }, $c }
sub inc { $_[0]->{n}++; return $_[0]; }
sub get { return $_[0]->{n}; }
package main;
for (my $i = 0; $i < 1000; $i++) {
    my $obj = Counter->new->inc->inc->inc;
    my $n = $obj->get;
}
print "ok\n";
