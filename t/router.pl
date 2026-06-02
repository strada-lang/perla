use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Simple router
package Router;

sub new {
    my ($class) = @_;
    return bless({ routes => [] }, $class);
}

sub add_route {
    my ($self, $method, $path, $handler) = @_;
    push(@{$self->{routes}}, {
        method  => $method,
        path    => $path,
        handler => $handler,
    });
}

sub match {
    my ($self, $method, $path) = @_;
    foreach my $route (@{$self->{routes}}) {
        if ($route->{method} eq $method && $route->{path} eq $path) {
            return $route->{handler};
        }
    }
    return undef;
}

# Request/Response objects
package Request;
sub new {
    my ($class, %args) = @_;
    return bless({ method => $args{method} || "GET", path => $args{path} || "/", params => $args{params} || {} }, $class);
}
sub method { return $_[0]->{method}; }
sub path { return $_[0]->{path}; }
sub param { return $_[0]->{params}{$_[1]}; }

package Response;
sub new {
    my ($class, %args) = @_;
    return bless({ status => $args{status} || 200, body => $args{body} || "" }, $class);
}
sub status { return $_[0]->{status}; }
sub body { return $_[0]->{body}; }

package main;

# Setup router
my $router = Router::new("Router");
$router->add_route("GET", "/", sub { return Response::new("Response", status => 200, body => "Home"); });
$router->add_route("GET", "/about", sub { return Response::new("Response", status => 200, body => "About"); });
$router->add_route("POST", "/api/data", sub { return Response::new("Response", status => 201, body => "Created"); });

# Test routing
my $handler = $router->match("GET", "/");
ok(defined($handler), "route matched /");
my $resp = $handler->();
ok($resp->status() == 200, "status 200");
ok($resp->body() eq "Home", "body Home");

$handler = $router->match("GET", "/about");
ok(defined($handler), "route matched /about");
$resp = $handler->();
ok($resp->body() eq "About", "body About");

$handler = $router->match("POST", "/api/data");
ok(defined($handler), "route matched POST");
$resp = $handler->();
ok($resp->status() == 201, "status 201");
ok($resp->body() eq "Created", "body Created");

$handler = $router->match("GET", "/missing");
ok(!defined($handler), "no match for /missing");

# Test request object
my $req = Request::new("Request", method => "POST", path => "/submit", params => { name => "Alice", age => "30" });
ok($req->method() eq "POST", "req method");
ok($req->path() eq "/submit", "req path");
ok($req->param("name") eq "Alice", "req param name");
ok($req->param("age") eq "30", "req param age");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All router tests passed!\n"; }
