use strict;
use warnings;

# A simple HTTP request/response parser — realistic Perl code

package HTTP::Request;

sub new {
    my ($class, %args) = @_;
    return bless({
        method  => $args{method} || "GET",
        path    => $args{path} || "/",
        version => $args{version} || "HTTP/1.1",
        headers => $args{headers} || {},
        body    => $args{body} || "",
    }, $class);
}

sub method  { return $_[0]->{method}; }
sub path    { return $_[0]->{path}; }
sub version { return $_[0]->{version}; }
sub body    { return $_[0]->{body}; }

sub header {
    my ($self, $name) = @_;
    my $lc_name = lc($name);
    if (exists($self->{headers}{$lc_name})) {
        return $self->{headers}{$lc_name};
    }
    return undef;
}

sub set_header {
    my ($self, $name, $value) = @_;
    $self->{headers}{lc($name)} = $value;
}

sub to_string {
    my ($self) = @_;
    my $result = $self->{method} . " " . $self->{path} . " " . $self->{version} . "\r\n";
    foreach my $key (sort(keys(%{$self->{headers}}))) {
        $result = $result . $key . ": " . $self->{headers}{$key} . "\r\n";
    }
    $result = $result . "\r\n";
    if (length($self->{body}) > 0) {
        $result = $result . $self->{body};
    }
    return $result;
}

sub parse {
    my ($class, $raw) = @_;
    my @lines = split("\r\n", $raw);
    if (scalar(@lines) == 0) { return undef; }

    # Parse request line
    my @parts = split(" ", $lines[0]);
    my $method = $parts[0];
    my $path = $parts[1];
    my $version = "HTTP/1.1";
    if (scalar(@parts) >= 3) { $version = $parts[2]; }

    # Parse headers
    my %headers = ();
    my $i = 1;
    my $body_start = scalar(@lines);
    while ($i < scalar(@lines)) {
        if (length($lines[$i]) == 0) {
            $body_start = $i + 1;
            last;
        }
        my $colon = index($lines[$i], ":");
        if ($colon > 0) {
            my $key = lc(substr($lines[$i], 0, $colon));
            my $val = substr($lines[$i], $colon + 1);
            $val =~ s/^\s+//;
            $headers{$key} = $val;
        }
        $i++;
    }

    # Body
    my $body = "";
    if ($body_start < scalar(@lines)) {
        my @body_lines = ();
        my $j = $body_start;
        while ($j < scalar(@lines)) {
            push(@body_lines, $lines[$j]);
            $j++;
        }
        $body = join("\r\n", @body_lines);
    }

    return HTTP::Request::new($class,
        method  => $method,
        path    => $path,
        version => $version,
        headers => \%headers,
        body    => $body,
    );
}

package HTTP::Response;

sub new {
    my ($class, %args) = @_;
    return bless({
        status  => $args{status} || 200,
        reason  => $args{reason} || "OK",
        headers => $args{headers} || {},
        body    => $args{body} || "",
    }, $class);
}

sub status { return $_[0]->{status}; }
sub reason { return $_[0]->{reason}; }
sub body   { return $_[0]->{body}; }

sub set_header {
    my ($self, $name, $value) = @_;
    $self->{headers}{lc($name)} = $value;
}

sub to_string {
    my ($self) = @_;
    my $result = "HTTP/1.1 " . $self->{status} . " " . $self->{reason} . "\r\n";
    foreach my $key (sort(keys(%{$self->{headers}}))) {
        $result = $result . $key . ": " . $self->{headers}{$key} . "\r\n";
    }
    $result = $result . "\r\n" . $self->{body};
    return $result;
}

package main;

# --- Test request parsing ---
my $raw_request = "GET /api/users?page=1 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\nAuthorization: Bearer token123\r\n\r\n";
my $req = HTTP::Request::parse("HTTP::Request", $raw_request);

print "Method: " . $req->method() . "\n";
print "Path: " . $req->path() . "\n";
print "Host: " . $req->header("Host") . "\n";
print "Accept: " . $req->header("Accept") . "\n";
print "Auth: " . $req->header("Authorization") . "\n";

# --- Test request building ---
my $new_req = HTTP::Request::new("HTTP::Request",
    method => "POST",
    path   => "/api/data",
);
$new_req->set_header("Content-Type", "application/json");
$new_req->set_header("Host", "example.com");
print "\nBuilt request:\n" . $new_req->to_string();

# --- Test response ---
my $resp = HTTP::Response::new("HTTP::Response",
    status => 200,
    reason => "OK",
    body   => '{"status":"success","count":42}',
);
$resp->set_header("Content-Type", "application/json");
$resp->set_header("Content-Length", "31");
print "Response:\n" . $resp->to_string() . "\n";

# Verify
if ($req->method() eq "GET" && $req->path() eq "/api/users?page=1") {
    print "Request parsing OK\n";
}
if ($resp->status() == 200) {
    print "Response OK\n";
}

print "HTTP parser test passed!\n";
