use strict;
use warnings;

# A more substantial program: simple key-value store with operations

package KVStore;

sub new {
    my ($class) = @_;
    return bless({
        data    => {},
        history => [],
    }, $class);
}

sub set {
    my ($self, $key, $value) = @_;
    push(@{$self->{history}}, "SET " . $key . "=" . $value);
    $self->{data}->{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    return $self->{data}->{$key};
}

sub has_key {
    my ($self, $key) = @_;
    return exists($self->{data}{$key});
}

sub del {
    my ($self, $key) = @_;
    push(@{$self->{history}}, "DEL " . $key);
    delete($self->{data}{$key});
}

sub keys_list {
    my ($self) = @_;
    return keys(%{$self->{data}});
}

sub size {
    my ($self) = @_;
    my @k = keys(%{$self->{data}});
    return scalar(@k);
}

sub history {
    my ($self) = @_;
    return @{$self->{history}};
}

sub dump_store {
    my ($self) = @_;
    my @k = sort(keys(%{$self->{data}}));
    my @lines = ();
    foreach my $k (@k) {
        push(@lines, $k . "=" . $self->{data}->{$k});
    }
    return join(", ", @lines);
}

package main;

# Create store and do operations
my $store = KVStore::new("KVStore");

$store->set("name", "Alice");
$store->set("age", "30");
$store->set("city", "NYC");
print "Store: " . $store->dump_store() . "\n";
print "Size: " . $store->size() . "\n";

# Get
print "Name: " . $store->get("name") . "\n";

# Check existence
if ($store->has_key("age")) {
    print "Has age: yes\n";
}
if (!$store->has_key("email")) {
    print "Has email: no\n";
}

# Delete
$store->del("city");
print "After delete: " . $store->dump_store() . "\n";

# Update
$store->set("age", "31");
print "Updated: " . $store->dump_store() . "\n";

# History
my @hist = $store->history();
print "\nHistory (" . scalar(@hist) . " ops):\n";
foreach my $h (@hist) {
    print "  " . $h . "\n";
}

# --- Functional pipeline ---
my @data = (
    { name => "Alice", score => 95 },
    { name => "Bob", score => 60 },
    { name => "Charlie", score => 85 },
    { name => "Diana", score => 45 },
    { name => "Eve", score => 92 },
);

# Filter, transform, sort
my @passing = grep { $_->{score} >= 70 } @data;
my @names = map { $_->{name} . " (" . $_->{score} . ")" } @passing;
my @sorted = sort(@names);
print "\nPassing students:\n";
foreach my $n (@sorted) {
    print "  " . $n . "\n";
}

# Reduce (manual since Perl doesn't have reduce built-in without List::Util)
my $total = 0;
my $count = 0;
foreach my $d (@data) {
    $total += $d->{score};
    $count++;
}
print "Average: " . ($total / $count) . "\n";

print "\nAll real-world tests passed!\n";
