use strict;
use warnings;

# String interpolation
my $name = "World";
print "Hello, $name!\n";

# Arithmetic and compound assignment
my $x = 10;
$x += 5;
$x -= 3;
print "x = " . $x . "\n";  # 12

# String concat assignment
my $greeting = "Hello";
$greeting .= ", World!";
print $greeting . "\n";

# Ternary
my $val = ($x > 10) ? "big" : "small";
print "val is " . $val . "\n";  # big

# Anonymous hash
my $person = { name => "Alice", age => 30 };
print "Name: " . $person->{name} . "\n";
print "Age: " . $person->{age} . "\n";

# Anonymous array
my $nums = [10, 20, 30];
print "First: " . $nums->[0] . "\n";

# Push/pop
my @arr = ();
push(@arr, "one");
push(@arr, "two");
push(@arr, "three");
my $last = pop(@arr);
print "Popped: " . $last . "\n";  # three

# Foreach
foreach my $item (@arr) {
    print "Item: " . $item . "\n";
}

# Sub with multiple args
sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

my $sum = add(3, 4);
print "3 + 4 = " . $sum . "\n";

# Nested sub calls
sub greet_person {
    my $who = shift;
    my $times = shift;
    my $i = 0;
    while ($i < $times) {
        print "Hi, " . $who . "!\n";
        $i++;
    }
}

greet_person("Bob", 2);

print "Done!\n";
