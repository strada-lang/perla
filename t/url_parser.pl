use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# URL parser
sub parse_url {
    my ($url) = @_;
    my %result = ();
    
    # Extract scheme
    if ($url =~ /^(\w+):\/\//) {
        $result{scheme} = $1;
        $url = substr($url, length($1) + 3);
    }
    
    # Extract path
    my $path_pos = index($url, "/");
    if ($path_pos >= 0) {
        $result{path} = substr($url, $path_pos);
        $url = substr($url, 0, $path_pos);
    } else {
        $result{path} = "/";
    }
    
    # Extract query string from path
    my $q_pos = index($result{path}, "?");
    if ($q_pos >= 0) {
        $result{query} = substr($result{path}, $q_pos + 1);
        $result{path} = substr($result{path}, 0, $q_pos);
    }
    
    # Extract port
    my $port_pos = index($url, ":");
    if ($port_pos >= 0) {
        $result{port} = substr($url, $port_pos + 1) + 0;
        $result{host} = substr($url, 0, $port_pos);
    } else {
        $result{host} = $url;
        $result{port} = ($result{scheme} eq "https") ? 443 : 80;
    }
    
    return %result;
}

# Query string parser
sub parse_query {
    my ($qs) = @_;
    my %params = ();
    if (!defined($qs) || length($qs) == 0) { return %params; }
    my @pairs = split(/&/, $qs);
    foreach my $pair (@pairs) {
        my @kv = split(/=/, $pair);
        if (scalar(@kv) == 2) {
            $params{$kv[0]} = $kv[1];
        }
    }
    return %params;
}

# URL builder
sub build_url {
    my (%parts) = @_;
    my $url = $parts{scheme} . "://" . $parts{host};
    if (defined($parts{port})) {
        my $default_port = ($parts{scheme} eq "https") ? 443 : 80;
        if ($parts{port} != $default_port) {
            $url .= ":" . $parts{port};
        }
    }
    $url .= $parts{path};
    if (defined($parts{query}) && length($parts{query}) > 0) {
        $url .= "?" . $parts{query};
    }
    return $url;
}

# Test URL parsing
my %u1 = parse_url("https://example.com/api/users?page=1&limit=10");
ok($u1{scheme} eq "https", "scheme");
ok($u1{host} eq "example.com", "host");
ok($u1{port} == 443, "default https port");
ok($u1{path} eq "/api/users", "path");
ok($u1{query} eq "page=1&limit=10", "query");

my %u2 = parse_url("http://localhost:8080/index.html");
ok($u2{scheme} eq "http", "http scheme");
ok($u2{host} eq "localhost", "localhost");
ok($u2{port} == 8080, "custom port");
ok($u2{path} eq "/index.html", "path with ext");

# Test query parsing
my %q = parse_query($u1{query});
ok($q{page} eq "1", "query param page");
ok($q{limit} eq "10", "query param limit");

# Test URL building
my $rebuilt = build_url(%u1);
ok($rebuilt eq "https://example.com/api/users?page=1&limit=10", "rebuild url: " . $rebuilt);

my $rebuilt2 = build_url(%u2);
ok($rebuilt2 eq "http://localhost:8080/index.html", "rebuild custom port: " . $rebuilt2);

# Edge cases
my %u3 = parse_url("http://example.com");
ok($u3{host} eq "example.com", "no path host");
ok($u3{path} eq "/", "no path default");
ok($u3{port} == 80, "http default port");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All HTTP tests passed!\n"; }
