package MyApp::Model;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    return bless({
        id   => $args{id} || 0,
        data => $args{data} || {},
    }, $class);
}

sub id   { return $_[0]->{id}; }
sub data { return $_[0]->{data}; }

sub set {
    my ($self, $key, $value) = @_;
    $self->{data}{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    return $self->{data}{$key};
}

sub to_string {
    my ($self) = @_;
    my @parts = ();
    foreach my $k (sort(keys(%{$self->{data}}))) {
        push(@parts, $k . "=" . $self->{data}{$k});
    }
    return "Model#" . $self->{id} . "{" . join(", ", @parts) . "}";
}

1;
