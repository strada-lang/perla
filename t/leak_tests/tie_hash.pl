# Leak test: tied hash with FETCH/STORE/EXISTS/DELETE in a loop.

package H;
sub TIEHASH { my $c = shift; bless { _data => {} }, $c }
sub STORE   { $_[0]->{_data}->{$_[1]} = $_[2] }
sub FETCH   { $_[0]->{_data}->{$_[1]} }
sub EXISTS  { exists $_[0]->{_data}->{$_[1]} }
sub DELETE  { delete $_[0]->{_data}->{$_[1]} }

package main;
my %h;
tie %h, 'H';

for (my $i = 0; $i < 500; $i++) {
    $h{$i} = $i * 2;       # STORE
    my $v = $h{$i};        # FETCH
    my $e = exists $h{$i}; # EXISTS
    delete $h{$i};         # DELETE
}

print "ok\n";
