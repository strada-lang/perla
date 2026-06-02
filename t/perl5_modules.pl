use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Multiple inheritance ---
package Printable;
sub to_str { return "Printable"; }

package Comparable;
sub compare { return 0; }

package SortableItem;
our @ISA = ('Printable', 'Comparable');

sub new {
    my ($class, $val) = @_;
    return bless({ val => $val }, $class);
}
sub val { return $_[0]->{val}; }
sub to_str { return "Item(" . $_[0]->{val} . ")"; }
sub compare {
    my ($self, $other) = @_;
    return $self->{val} - $other->{val};
}

package main;

my $a = SortableItem::new("SortableItem", 10);
my $b = SortableItem::new("SortableItem", 20);
ok($a->to_str() eq "Item(10)", "sortable to_str override");
ok($a->compare($b) == -10, "sortable compare");

# --- Factory pattern ---
package Shape;

sub create {
    my ($class, $type, %args) = @_;
    if ($type eq "circle") {
        return Circle2::new("Circle2", radius => $args{radius});
    } elsif ($type eq "rect") {
        return Rect2::new("Rect2", width => $args{width}, height => $args{height});
    }
    return undef;
}

package Circle2;
our @ISA = ('Shape');
sub new {
    my ($class, %args) = @_;
    return bless({ radius => $args{radius} || 1 }, $class);
}
sub area { return 3.14159 * $_[0]->{radius} * $_[0]->{radius}; }
sub describe { return "circle r=" . $_[0]->{radius}; }

package Rect2;
our @ISA = ('Shape');
sub new {
    my ($class, %args) = @_;
    return bless({ width => $args{width} || 1, height => $args{height} || 1 }, $class);
}
sub area { return $_[0]->{width} * $_[0]->{height}; }
sub describe { return "rect " . $_[0]->{width} . "x" . $_[0]->{height}; }

package main;

my $c = Shape::create("Shape", "circle", radius => 5);
my $r = Shape::create("Shape", "rect", width => 3, height => 4);
ok($c->describe() eq "circle r=5", "factory circle");
ok($r->describe() eq "rect 3x4", "factory rect");
ok($c->area() > 78 && $c->area() < 79, "circle area");
ok($r->area() == 12, "rect area");

# --- Event emitter with anonymous sub callbacks ---
package EventEmitter;
sub new { return bless({ handlers => {} }, "EventEmitter"); }
sub on {
    my ($self, $event, $handler) = @_;
    if (!exists($self->{handlers}{$event})) {
        $self->{handlers}{$event} = [];
    }
    push(@{$self->{handlers}{$event}}, $handler);
}
sub emit {
    my ($self, $event, $data) = @_;
    if (exists($self->{handlers}{$event})) {
        foreach my $handler (@{$self->{handlers}{$event}}) {
            $handler->($data);
        }
    }
}

package main;

# Use our so closures can capture
our @event_log = ();
my $emitter = EventEmitter::new("EventEmitter");
$emitter->on("data", sub { push(@event_log, "got:" . $_[0]); });
$emitter->on("data", sub { push(@event_log, "also:" . $_[0]); });
$emitter->emit("data", "hello");
$emitter->emit("data", "world");
ok(scalar(@event_log) == 4, "event emitter count");
ok($event_log[0] eq "got:hello", "event 1");
ok($event_log[1] eq "also:hello", "event 2");
ok($event_log[2] eq "got:world", "event 3");

# --- Chained builders with state ---
package QueryBuilder;
sub new { return bless({ table => "", wheres => [], order => "", limit => 0 }, "QueryBuilder"); }
sub from {
    my ($self, $table) = @_;
    $self->{table} = $table;
    return $self;
}
sub where {
    my ($self, $cond) = @_;
    push(@{$self->{wheres}}, $cond);
    return $self;
}
sub order_by {
    my ($self, $col) = @_;
    $self->{order} = $col;
    return $self;
}
sub limit_to {
    my ($self, $n) = @_;
    $self->{limit} = $n;
    return $self;
}
sub to_sql {
    my ($self) = @_;
    my $sql = "SELECT * FROM " . $self->{table};
    if (scalar(@{$self->{wheres}}) > 0) {
        $sql = $sql . " WHERE " . join(" AND ", @{$self->{wheres}});
    }
    if (length($self->{order}) > 0) {
        $sql = $sql . " ORDER BY " . $self->{order};
    }
    if ($self->{limit} > 0) {
        $sql = $sql . " LIMIT " . $self->{limit};
    }
    return $sql;
}

package main;

my $query = QueryBuilder::new("QueryBuilder")
    ->from("users")
    ->where("age > 18")
    ->where("active = 1")
    ->order_by("name")
    ->limit_to(10)
    ->to_sql();
ok($query eq "SELECT * FROM users WHERE age > 18 AND active = 1 ORDER BY name LIMIT 10", "query builder");

# --- String processing with regex ---
my @emails = ("alice\@example.com", "bob\@test.org", "charlie\@example.com", "invalid", "dave\@test.org");
my @valid = grep { $_ =~ /\w+\@\w+\.\w+/ } @emails;
ok(scalar(@valid) == 4, "email filter count");

my @example_users = map { $_ =~ /^(\w+)\@/; $1 } grep { $_ =~ /\@example\.com/ } @emails;
ok(scalar(@example_users) == 2, "example.com users");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All module tests passed!\n"; }
