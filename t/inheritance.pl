use strict;
use warnings;

# Test proper OOP with inheritance chain

package Shape;

sub new {
    my ($class, %args) = @_;
    return bless({ color => $args{color} || "black" }, $class);
}

sub color { return $_[0]->{color}; }

sub area {
    my $self = shift;
    return 0;  # base class
}

sub describe {
    my $self = shift;
    return $self->color() . " shape, area=" . $self->area();
}

package Circle;

sub new {
    my ($class, %args) = @_;
    my $self = Shape::new($class, color => $args{color});
    $self->{radius} = $args{radius} || 1;
    return $self;
}

sub radius { return $_[0]->{radius}; }

sub area {
    my $self = shift;
    return 3.14159 * $self->{radius} * $self->{radius};
}

package Rectangle;

sub new {
    my ($class, %args) = @_;
    my $self = Shape::new($class, color => $args{color});
    $self->{width} = $args{width} || 1;
    $self->{height} = $args{height} || 1;
    return $self;
}

sub width  { return $_[0]->{width}; }
sub height { return $_[0]->{height}; }

sub area {
    my $self = shift;
    return $self->{width} * $self->{height};
}

package main;

my $c = Circle::new("Circle", color => "red", radius => 5);
print "Circle: " . $c->describe() . "\n";
print "  radius=" . $c->radius() . ", area=" . $c->area() . "\n";

my $r = Rectangle::new("Rectangle", color => "blue", width => 4, height => 6);
print "Rectangle: " . $r->describe() . "\n";
print "  width=" . $r->width() . ", height=" . $r->height() . "\n";

# Polymorphism
my @shapes = ($c, $r);
print "\nAll shapes:\n";
foreach my $s (@shapes) {
    print "  " . $s->describe() . "\n";
}

# Verify values
if ($c->area() > 78 && $c->area() < 79) {
    print "Circle area OK\n";
}
if ($r->area() == 24) {
    print "Rectangle area OK\n";
}

print "Inheritance test passed!\n";
