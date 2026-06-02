package MyApp::User;

use strict;
use warnings;
use parent 'MyApp::Model';

sub new {
    my ($class, %args) = @_;
    my $self = MyApp::Model::new($class, id => $args{id});
    $self->set("name", $args{name} || "Anonymous");
    $self->set("email", $args{email} || "");
    return $self;
}

sub name  { return $_[0]->get("name"); }
sub email { return $_[0]->get("email"); }

sub greeting {
    my ($self) = @_;
    return "Hello, " . $self->name() . "!";
}

1;
