use strict;
use warnings;

# Complete TODO app with persistence, search, tags, and reporting

package Todo::Item;

sub new {
    my ($class, %args) = @_;
    return bless({
        id        => $args{id} || 0,
        title     => $args{title} || "",
        done      => $args{done} || 0,
        priority  => $args{priority} || "medium",
        tags      => $args{tags} || [],
        created   => $args{created} || "2024-01-01",
    }, $class);
}

sub id       { return $_[0]->{id}; }
sub title    { return $_[0]->{title}; }
sub done     { return $_[0]->{done}; }
sub priority { return $_[0]->{priority}; }
sub tags     { return $_[0]->{tags}; }
sub created  { return $_[0]->{created}; }

sub mark_done { $_[0]->{done} = 1; }
sub mark_undone { $_[0]->{done} = 0; }

sub has_tag {
    my ($self, $tag) = @_;
    foreach my $t (@{$self->{tags}}) {
        if ($t eq $tag) { return 1; }
    }
    return 0;
}

sub to_string {
    my ($self) = @_;
    my $status = $self->{done} ? "[x]" : "[ ]";
    my $tag_str = "";
    if (scalar(@{$self->{tags}}) > 0) {
        $tag_str = " [" . join(",", @{$self->{tags}}) . "]";
    }
    return sprintf("%s #%d (%s) %s%s", $status, $self->{id}, $self->{priority}, $self->{title}, $tag_str);
}

sub serialize {
    my ($self) = @_;
    return $self->{id} . "|" . $self->{title} . "|" . $self->{done} . "|" .
           $self->{priority} . "|" . join(",", @{$self->{tags}}) . "|" . $self->{created};
}

package Todo::List;

sub new {
    my ($class) = @_;
    return bless({
        items   => [],
        next_id => 1,
    }, $class);
}

sub add {
    my ($self, %args) = @_;
    $args{id} = $self->{next_id};
    $self->{next_id} += 1;
    my $item = Todo::Item::new("Todo::Item", %args);
    push(@{$self->{items}}, $item);
    return $item;
}

sub get {
    my ($self, $id) = @_;
    foreach my $item (@{$self->{items}}) {
        if ($item->id() == $id) { return $item; }
    }
    return undef;
}

sub remove {
    my ($self, $id) = @_;
    my @new_items = ();
    foreach my $item (@{$self->{items}}) {
        if ($item->id() != $id) {
            push(@new_items, $item);
        }
    }
    $self->{items} = \@new_items;
}

sub all { return @{$_[0]->{items}}; }

sub count { return scalar(@{$_[0]->{items}}); }

sub pending {
    my ($self) = @_;
    return grep { !$_->done() } @{$self->{items}};
}

sub completed {
    my ($self) = @_;
    return grep { $_->done() } @{$self->{items}};
}

sub by_priority {
    my ($self, $pri) = @_;
    return grep { $_->priority() eq $pri } @{$self->{items}};
}

sub by_tag {
    my ($self, $tag) = @_;
    return grep { $_->has_tag($tag) } @{$self->{items}};
}

sub search {
    my ($self, $query) = @_;
    my $lc_query = lc($query);
    return grep { index(lc($_->title()), $lc_query) >= 0 } @{$self->{items}};
}

sub report {
    my ($self) = @_;
    my @lines = ();
    push(@lines, "=== TODO Report ===");
    push(@lines, "Total: " . $self->count());
    my @pend = $self->pending();
    my @comp = $self->completed();
    push(@lines, "Pending: " . scalar(@pend));
    push(@lines, "Completed: " . scalar(@comp));

    # By priority
    my @high = $self->by_priority("high");
    my @med = $self->by_priority("medium");
    my @low = $self->by_priority("low");
    push(@lines, "");
    push(@lines, "Priority breakdown:");
    push(@lines, "  High: " . scalar(@high));
    push(@lines, "  Medium: " . scalar(@med));
    push(@lines, "  Low: " . scalar(@low));

    # Pending items
    if (scalar(@pend) > 0) {
        push(@lines, "");
        push(@lines, "Pending items:");
        foreach my $item (@pend) {
            push(@lines, "  " . $item->to_string());
        }
    }

    push(@lines, "===================");
    return join("\n", @lines);
}

sub save_to_file {
    my ($self, $filename) = @_;
    my $fh;
    open($fh, ">", $filename);
    foreach my $item (@{$self->{items}}) {
        print $fh $item->serialize() . "\n";
    }
    close($fh);
}

sub load_from_file {
    my ($self, $filename) = @_;
    if (!-e $filename) { return; }
    my $fh;
    open($fh, "<", $filename);
    my $line = <$fh>;
    while (defined($line)) {
        chomp($line);
        if (length($line) > 0) {
            my @parts = split("\\|", $line);
            if (scalar(@parts) >= 6) {
                my @tags = ();
                if (length($parts[4]) > 0) {
                    @tags = split(",", $parts[4]);
                }
                my $item = Todo::Item::new("Todo::Item",
                    id       => int($parts[0]),
                    title    => $parts[1],
                    done     => int($parts[2]),
                    priority => $parts[3],
                    tags     => \@tags,
                    created  => $parts[5],
                );
                push(@{$self->{items}}, $item);
                if (int($parts[0]) >= $self->{next_id}) {
                    $self->{next_id} = int($parts[0]) + 1;
                }
            }
        }
        $line = <$fh>;
    }
    close($fh);
}

package main;

# Create a TODO list
my $list = Todo::List::new("Todo::List");

# Add items
$list->add(title => "Buy groceries", priority => "high", tags => ["personal", "errands"]);
$list->add(title => "Write tests", priority => "high", tags => ["work", "coding"]);
$list->add(title => "Read book", priority => "low", tags => ["personal"]);
$list->add(title => "Deploy v2.0", priority => "high", tags => ["work", "urgent"]);
$list->add(title => "Clean house", priority => "medium", tags => ["personal"]);
$list->add(title => "Code review", priority => "medium", tags => ["work", "coding"]);

# Mark some as done
$list->get(1)->mark_done();
$list->get(3)->mark_done();

# Print report
print $list->report() . "\n\n";

# Search
my @coding = $list->by_tag("coding");
print "Coding tasks: " . scalar(@coding) . "\n";
foreach my $item (@coding) {
    print "  " . $item->to_string() . "\n";
}

my @found = $list->search("deploy");
print "\nSearch 'deploy': " . scalar(@found) . " results\n";
foreach my $item (@found) {
    print "  " . $item->to_string() . "\n";
}

# Save and reload
my $tmpfile = "/tmp/perla_todo_test.dat";
$list->save_to_file($tmpfile);

my $list2 = Todo::List::new("Todo::List");
$list2->load_from_file($tmpfile);
print "\nLoaded " . $list2->count() . " items from file\n";

# Verify loaded data
my $loaded_item = $list2->get(4);
if (defined($loaded_item)) {
    print "Item 4: " . $loaded_item->title() . " (" . $loaded_item->priority() . ")\n";
}

# Clean up
unlink($tmpfile);

# Verify counts
my @pend = $list->pending();
my @comp = $list->completed();
if (scalar(@pend) == 4 && scalar(@comp) == 2) {
    print "\nAll todo_app tests passed!\n";
} else {
    print "\nFAIL: pending=" . scalar(@pend) . " completed=" . scalar(@comp) . "\n";
}
