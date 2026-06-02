use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: " . $n . "\n"; } }

# In-memory Store
package Store;
sub new { return bless({data => {}, next_id => 1}, $_[0]); }
sub create {
    my ($self, %attrs) = @_;
    my $id = $self->{next_id}++;
    $attrs{id} = $id;
    $self->{data}{$id} = \%attrs;
    return $id;
}
sub find { return $_[0]->{data}{$_[1]}; }
sub update {
    my ($self, $id, %attrs) = @_;
    my $rec = $self->{data}{$id};
    return 0 unless defined($rec);
    for my $k (keys %attrs) { $rec->{$k} = $attrs{$k}; }
    return 1;
}
sub delete {
    my ($self, $id) = @_;
    if (exists $self->{data}{$id}) { delete $self->{data}{$id}; return 1; }
    return 0;
}
sub count { return scalar(keys %{$_[0]->{data}}); }
sub find_by {
    my ($self, $field, $value) = @_;
    my @results;
    for my $rec (values %{$self->{data}}) {
        if (defined($rec->{$field}) && $rec->{$field} eq $value) {
            push(@results, $rec);
        }
    }
    return @results;
}

package main;

my $store = Store->new();
my $id1 = $store->create(name => "Alice", role => "admin");
my $id2 = $store->create(name => "Bob", role => "user");
ok($store->count() == 2, "store count");

my $rec = $store->find($id1);
ok($rec->{name} eq "Alice", "find");

$store->update($id1, name => "Alice Smith");
ok($store->find($id1)->{name} eq "Alice Smith", "update");

$store->delete($id2);
ok($store->count() == 1, "delete");

$store->create(name => "Carol", role => "admin");
$store->create(name => "Dave", role => "admin");
my @admins = $store->find_by("role", "admin");
ok(scalar(@admins) >= 2, "find_by");

# Report
print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All MVC tests passed!\n"; }
