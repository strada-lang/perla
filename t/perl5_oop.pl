use strict;
use warnings;

our $pass = 0;
our $fail = 0;

sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Inheritance with @ISA ---
package Animal;

sub new {
    my ($class, %args) = @_;
    return bless({ name => $args{name}, sound => $args{sound} }, $class);
}

sub name { return $_[0]->{name}; }
sub sound { return $_[0]->{sound}; }
sub speak {
    my $self = shift;
    return $self->name() . " says " . $self->sound();
}
sub type { return "Animal"; }

package Dog;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} = "Woof";
    return Animal::new($class, %args);
}

sub fetch { return $_[0]->name() . " fetches!"; }

package Cat;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} = "Meow";
    return Animal::new($class, %args);
}

sub purr { return $_[0]->name() . " purrs..."; }

package main;

# Test basic OOP
my $dog = Dog::new("Dog", name => "Rex");
my $cat = Cat::new("Cat", name => "Whiskers");

ok($dog->name() eq "Rex", "dog name");
ok($dog->sound() eq "Woof", "dog sound");
ok($dog->speak() eq "Rex says Woof", "dog speak (inherited)");
ok($dog->fetch() eq "Rex fetches!", "dog fetch (own)");

ok($cat->name() eq "Whiskers", "cat name");
ok($cat->speak() eq "Whiskers says Meow", "cat speak (inherited)");
ok($cat->purr() eq "Whiskers purrs...", "cat purr (own)");

# Test polymorphism
my @animals = ($dog, $cat);
my @sounds = ();
foreach my $a (@animals) {
    push(@sounds, $a->speak());
}
ok(join(", ", @sounds) eq "Rex says Woof, Whiskers says Meow", "polymorphic speak");

# --- Multi-level hash construction with methods ---
package Counter;

sub new {
    my ($class) = @_;
    return bless({ count => 0, history => [] }, $class);
}

sub increment {
    my ($self, $amount) = @_;
    if (!defined($amount)) { $amount = 1; }
    $self->{count} += $amount;
    push(@{$self->{history}}, $self->{count});
    return $self->{count};
}

sub count { return $_[0]->{count}; }
sub history {
    my ($self) = @_;
    return join(", ", @{$self->{history}});
}

sub reset_counter {
    my ($self) = @_;
    $self->{count} = 0;
    $self->{history} = [];
}

package main;

my $c = Counter::new("Counter");
$c->increment();
$c->increment();
$c->increment(5);
ok($c->count() == 7, "counter count");
ok($c->history() eq "1, 2, 7", "counter history");
$c->reset_counter();
ok($c->count() == 0, "counter reset");

# --- Method chaining via return $self ---
package Builder;

sub new {
    my ($class) = @_;
    return bless({ parts => [] }, $class);
}

sub add {
    my ($self, $part) = @_;
    push(@{$self->{parts}}, $part);
    return $self;
}

sub build {
    my ($self) = @_;
    return join(" + ", @{$self->{parts}});
}

package main;

my $result = Builder::new("Builder")->add("A")->add("B")->add("C")->build();
ok($result eq "A + B + C", "method chaining");

# --- File test: -e ---
ok(-e "/tmp", "-e /tmp exists");
ok(!-e "/nonexistent_path_xyz", "-e nonexistent");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All OOP tests passed!\n"; }
