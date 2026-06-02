use strict;
use warnings;

my $name = "World";
my $count = 3;

print "Hello, " . $name . "!\n";

my $i = 0;
while ($i < $count) {
    print "iteration " . $i . "\n";
    $i++;
}

sub greet {
    my $who = shift;
    return "Greetings, " . $who . "!";
}

my $msg = greet("Perla");
print $msg . "\n";
