use strict;
use warnings;

# Linked list implementation — tests deep OOP and pointer-like patterns

package Node;

sub new {
    my ($class, $value) = @_;
    return bless({ value => $value, next => undef }, $class);
}

sub value { return $_[0]->{value}; }

sub next_node { return $_[0]->{next}; }

sub set_next {
    my ($self, $node) = @_;
    $self->{next} = $node;
}

package LinkedList;

sub new {
    my ($class) = @_;
    return bless({ head => undef, size => 0 }, $class);
}

sub push_front {
    my ($self, $value) = @_;
    my $node = Node::new("Node", $value);
    $node->set_next($self->{head});
    $self->{head} = $node;
    $self->{size} += 1;
}

sub push_back {
    my ($self, $value) = @_;
    my $node = Node::new("Node", $value);
    if (!defined($self->{head})) {
        $self->{head} = $node;
    } else {
        my $current = $self->{head};
        while (defined($current->next_node())) {
            $current = $current->next_node();
        }
        $current->set_next($node);
    }
    $self->{size} += 1;
}

sub pop_front {
    my ($self) = @_;
    if (!defined($self->{head})) { return undef; }
    my $value = $self->{head}->value();
    $self->{head} = $self->{head}->next_node();
    $self->{size} -= 1;
    return $value;
}

sub size { return $_[0]->{size}; }

sub to_array {
    my ($self) = @_;
    my @result = ();
    my $current = $self->{head};
    while (defined($current)) {
        push(@result, $current->value());
        $current = $current->next_node();
    }
    return @result;
}

sub contains {
    my ($self, $target) = @_;
    my $current = $self->{head};
    while (defined($current)) {
        if ($current->value() eq $target) {
            return 1;
        }
        $current = $current->next_node();
    }
    return 0;
}

sub to_string {
    my ($self) = @_;
    my @items = $self->to_array();
    return join(" -> ", @items) . " -> nil";
}

package main;

# Build a linked list
my $list = LinkedList::new("LinkedList");
$list->push_back("a");
$list->push_back("b");
$list->push_back("c");
$list->push_front("z");

print "List: " . $list->to_string() . "\n";
print "Size: " . $list->size() . "\n";

# Contains
print "Contains 'b': " . $list->contains("b") . "\n";
print "Contains 'x': " . $list->contains("x") . "\n";

# Pop front
my $popped = $list->pop_front();
print "Popped: " . $popped . "\n";
print "After pop: " . $list->to_string() . "\n";
print "Size: " . $list->size() . "\n";

# To array
my @arr = $list->to_array();
print "Array: " . join(", ", @arr) . "\n";

# Build numeric list and sum it
my $nums = LinkedList::new("LinkedList");
my $i = 1;
while ($i <= 5) {
    $nums->push_back($i);
    $i++;
}
print "Nums: " . $nums->to_string() . "\n";

my @num_arr = $nums->to_array();
my $sum = 0;
foreach my $n (@num_arr) {
    $sum += $n;
}
print "Sum: " . $sum . "\n";

print "Linked list test passed!\n";
