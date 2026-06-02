use strict;
use warnings;

# Simple OOP test

package Animal;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name  => $args{name},
        sound => $args{sound},
        legs  => $args{legs},
    };
    return bless($self, $class);
}

sub name  { my $self = shift; return $self->{name}; }
sub sound { my $self = shift; return $self->{sound}; }
sub legs  { my $self = shift; return $self->{legs}; }

sub speak {
    my $self = shift;
    print $self->{name} . " says " . $self->{sound} . "\n";
}

package Dog;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} = "Woof!";
    return Animal::new($class, %args);
}

sub fetch {
    my $self = shift;
    print $self->{name} . " fetches the ball!\n";
}

package main;

my $dog = Dog::new("Dog", name => "Rex", legs => 4, sound => "Bark");
$dog->speak();
$dog->fetch();
print "Name: " . $dog->name() . "\n";
print "Legs: " . $dog->legs() . "\n";
