my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# JSON encoder
sub json_encode {
    my ($val) = @_;
    if (!defined($val)) { return "null"; }
    if (ref($val) eq "HASH") {
        my @pairs;
        for my $k (sort keys %$val) { push(@pairs, "\"$k\":" . json_encode($val->{$k})); }
        return "{" . join(",", @pairs) . "}";
    }
    if (ref($val) eq "ARRAY") {
        my @items = map { json_encode($_) } @$val;
        return "[" . join(",", @items) . "]";
    }
    if ($val =~ /^-?\d+$/) { return "$val"; }
    if ($val =~ /^-?\d+\.\d+$/) { return "$val"; }
    my $e = $val;
    $e =~ s/\\/\\\\/g;
    $e =~ s/"/\\"/g;
    $e =~ s/\n/\\n/g;
    return "\"$e\"";
}

ok(json_encode({a => 1}) eq '{"a":1}', "encode hash");
ok(json_encode([1, 2, 3]) eq "[1,2,3]", "encode array");
ok(json_encode("hello") eq '"hello"', "encode string");
ok(json_encode(undef) eq "null", "encode null");

my $complex = json_encode({users => [{name => "Alice"}, {name => "Bob"}], count => 2});
ok($complex =~ /"count":2/, "encode nested");
ok($complex =~ /"users":\[/, "encode nested arr");

# Roundtrip test (encode then verify structure)
my $data = {name => "Alice", scores => [90, 85, 95], meta => {active => 1}};
my $json = json_encode($data);
ok($json =~ /"name":"Alice"/, "roundtrip name");
ok($json =~ /"scores":\[90,85,95\]/, "roundtrip scores");
ok($json =~ /"active":1/, "roundtrip meta");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All JSON2 tests passed!\n"; }
