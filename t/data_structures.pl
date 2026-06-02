use strict;
use warnings;

# Advanced data structure operations

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Binary search ---
sub binary_search {
    my ($arr_ref, $target) = @_;
    my $low = 0;
    my $high = scalar(@{$arr_ref}) - 1;
    while ($low <= $high) {
        my $mid = int(($low + $high) / 2);
        my $val = $arr_ref->[$mid];
        if ($val == $target) { return $mid; }
        elsif ($val < $target) { $low = $mid + 1; }
        else { $high = $mid - 1; }
    }
    return -1;
}

my @sorted = (2, 5, 8, 12, 16, 23, 38, 56, 72, 91);
ok(binary_search(\@sorted, 23) == 5, "binary search found");
ok(binary_search(\@sorted, 2) == 0, "binary search first");
ok(binary_search(\@sorted, 91) == 9, "binary search last");
ok(binary_search(\@sorted, 50) == -1, "binary search not found");

# --- Stack implementation ---
package Stack;
sub new { return bless({ items => [] }, "Stack"); }
sub push_item { my ($s, $v) = @_; push(@{$s->{items}}, $v); }
sub pop_item {
    my ($s) = @_;
    if (scalar(@{$s->{items}}) == 0) { return undef; }
    return pop(@{$s->{items}});
}
sub peek { my ($s) = @_; return $s->{items}[-1]; }
sub size { return scalar(@{$_[0]->{items}}); }
sub is_empty { return $_[0]->size() == 0; }

package main;

my $stack = Stack::new("Stack");
$stack->push_item(10);
$stack->push_item(20);
$stack->push_item(30);
ok($stack->size() == 3, "stack size");
ok($stack->peek() == 30, "stack peek");
ok($stack->pop_item() == 30, "stack pop");
ok($stack->size() == 2, "stack size after pop");

# --- Queue (FIFO) ---
package Queue;
sub new { return bless({ items => [] }, "Queue"); }
sub enqueue { my ($q, $v) = @_; push(@{$q->{items}}, $v); }
sub dequeue {
    my ($q) = @_;
    if (scalar(@{$q->{items}}) == 0) { return undef; }
    return shift(@{$q->{items}});
}
sub size { return scalar(@{$_[0]->{items}}); }

package main;

my $queue = Queue::new("Queue");
$queue->enqueue("first");
$queue->enqueue("second");
$queue->enqueue("third");
ok($queue->dequeue() eq "first", "queue FIFO");
ok($queue->dequeue() eq "second", "queue FIFO 2");
ok($queue->size() == 1, "queue size");

# --- Hash merge ---
sub merge_hashes {
    my @hashes = @_;
    my %result = ();
    foreach my $h (@hashes) {
        foreach my $k (keys(%{$h})) {
            $result{$k} = $h->{$k};
        }
    }
    return %result;
}

my %a_hash = ("a" => 1, "b" => 2);
my %b_hash = ("b" => 3, "c" => 4);
my %merged = merge_hashes(\%a_hash, \%b_hash);
ok($merged{"a"} == 1, "merge a");
ok($merged{"b"} == 3, "merge b (overwritten)");
ok($merged{"c"} == 4, "merge c");

# --- Simple flatten (one level) ---
sub flatten_one {
    my @result = ();
    foreach my $item (@_) {
        if (ref($item) eq "ARRAY") {
            foreach my $sub (@{$item}) {
                push(@result, $sub);
            }
        } else {
            push(@result, $item);
        }
    }
    return @result;
}

my @nested = (1, [2, 3], [4, 5], 6);
my @flat = flatten_one(@nested);
ok(join(",", @flat) eq "1,2,3,4,5,6", "flatten one level");

# --- String tokenizer ---
sub tokenize {
    my ($input) = @_;
    my @tokens = ();
    # Split into individual chars using substr
    my @chars = ();
    my $ci = 0;
    while ($ci < length($input)) {
        push(@chars, substr($input, $ci, 1));
        $ci++;
    }
    my $i = 0;
    while ($i < scalar(@chars)) {
        my $ch = $chars[$i];
        # Skip whitespace
        if ($ch eq " " || $ch eq "\t") {
            $i++;
            next;
        }
        # Number
        if ($ch ge "0" && $ch le "9") {
            my $num = "";
            while ($i < scalar(@chars) && $chars[$i] ge "0" && $chars[$i] le "9") {
                $num = $num . $chars[$i];
                $i++;
            }
            push(@tokens, { type => "NUM", value => $num });
            next;
        }
        # Operator
        if ($ch eq "+" || $ch eq "-" || $ch eq "*" || $ch eq "/") {
            push(@tokens, { type => "OP", value => $ch });
            $i++;
            next;
        }
        # Unknown
        push(@tokens, { type => "?", value => $ch });
        $i++;
    }
    return @tokens;
}

my @toks = tokenize("12 + 34 * 56");
ok(scalar(@toks) == 5, "tokenizer count");
ok($toks[0]->{type} eq "NUM", "tok 0 type");
ok($toks[0]->{value} eq "12", "tok 0 value");
ok($toks[1]->{type} eq "OP", "tok 1 type");
ok($toks[2]->{value} eq "34", "tok 2 value");
ok($toks[3]->{value} eq "*", "tok 3 value");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All data structure tests passed!\n"; }
