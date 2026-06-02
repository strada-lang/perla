use strict;
use warnings;

my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# HTTP Request Parser
package HTTP::Request;
sub parse {
    my ($class, $raw) = @_;
    my @lines = split(/\r?\n/, $raw);
    return undef unless scalar(@lines) > 0;

    # Parse request line
    my $req_line = shift(@lines);
    my @parts = split(/\s+/, $req_line);
    return undef unless scalar(@parts) >= 3;

    my $self = bless({
        method => $parts[0],
        path => $parts[1],
        version => $parts[2],
        headers => {},
        body => "",
    }, $class);

    # Parse headers
    my $in_body = 0;
    my @body_lines;
    for my $line (@lines) {
        if ($in_body) {
            push(@body_lines, $line);
            next;
        }
        if ($line eq "") {
            $in_body = 1;
            next;
        }
        if ($line =~ /^([^:]+):\s*(.*)$/) {
            $self->{headers}{lc($1)} = $2;
        }
    }
    $self->{body} = join("\n", @body_lines);
    return $self;
}
sub method { return $_[0]->{method}; }
sub path { return $_[0]->{path}; }
sub header { return $_[0]->{headers}{lc($_[1])} || ""; }
sub body { return $_[0]->{body}; }

# HTTP Response Builder
package HTTP::Response;
sub new {
    my ($class, $status) = @_;
    return bless({
        status => $status,
        headers => {},
        body => "",
    }, $class);
}
sub set_header {
    my ($self, $key, $val) = @_;
    $self->{headers}{$key} = $val;
    return $self;
}
sub set_body {
    my ($self, $body) = @_;
    $self->{body} = $body;
    $self->{headers}{"Content-Length"} = length($body);
    return $self;
}
sub to_string {
    my ($self) = @_;
    my $status_text = "OK";
    if ($self->{status} == 404) { $status_text = "Not Found"; }
    if ($self->{status} == 500) { $status_text = "Internal Server Error"; }
    my $out = "HTTP/1.1 " . $self->{status} . " " . $status_text . "\r\n";
    for my $key (sort keys %{$self->{headers}}) {
        $out .= $key . ": " . $self->{headers}{$key} . "\r\n";
    }
    $out .= "\r\n" . $self->{body};
    return $out;
}

# Tests
package main;

# Parse GET request
my $raw_get = "GET /api/users HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n";
my $req = HTTP::Request->parse($raw_get);
ok(defined($req), "parse GET");
ok($req->method() eq "GET", "method GET");
ok($req->path() eq "/api/users", "path");
ok($req->header("host") eq "example.com", "host header");
ok($req->header("accept") eq "application/json", "accept header");

# Parse POST request with body
my $raw_post = "POST /api/data HTTP/1.1\r\nHost: example.com\r\nContent-Type: application/json\r\nContent-Length: 13\r\n\r\n{\"key\":\"val\"}";
my $post = HTTP::Request->parse($raw_post);
ok($post->method() eq "POST", "method POST");
ok($post->header("content-type") eq "application/json", "content-type");
ok($post->body() eq '{"key":"val"}', "POST body: " . $post->body());

# Build response
my $resp = HTTP::Response->new(200);
$resp->set_header("Content-Type", "text/html");
$resp->set_body("<h1>Hello</h1>");
my $raw_resp = $resp->to_string();
ok($raw_resp =~ /HTTP\/1.1 200 OK/, "response status");
ok($raw_resp =~ /Content-Type: text\/html/, "response header");
ok($raw_resp =~ /<h1>Hello<\/h1>/, "response body");

# 404 response
my $not_found = HTTP::Response->new(404);
$not_found->set_body("Not Found");
ok($not_found->to_string() =~ /404 Not Found/, "404 response");

# URL parsing
sub parse_url {
    my ($url) = @_;
    my %result = (path => "/", query => "", fragment => "");
    if ($url =~ /^([^?#]+)/) { $result{path} = $1; }
    if ($url =~ /\?([^#]+)/) { $result{query} = $1; }
    if ($url =~ /#(.+)$/) { $result{fragment} = $1; }
    return %result;
}

my %url = parse_url("/search?q=hello&lang=en#results");
ok($url{path} eq "/search", "url path");
ok($url{query} eq "q=hello&lang=en", "url query");
ok($url{fragment} eq "results", "url fragment");

# Query string parsing
sub parse_qs {
    my ($qs) = @_;
    my %params;
    for my $pair (split(/&/, $qs)) {
        if ($pair =~ /^([^=]+)=(.*)$/) {
            $params{$1} = $2;
        }
    }
    return %params;
}

my %params = parse_qs("q=hello&lang=en&page=1");
ok($params{q} eq "hello", "qs param q");
ok($params{lang} eq "en", "qs param lang");
ok($params{page} eq "1", "qs param page");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All HTTP tests passed!\n"; }
