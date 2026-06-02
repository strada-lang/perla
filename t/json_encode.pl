use strict;
use warnings;

# Simple JSON encoder/decoder in pure Perl — tests many language features
our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

sub json_encode {
    my ($val) = @_;
    if (!defined($val)) { return "null"; }
    if (ref($val) eq "HASH") {
        my @pairs = ();
        foreach my $k (sort(keys(%{$val}))) {
            push(@pairs, "\"" . $k . "\":" . json_encode($val->{$k}));
        }
        return "{" . join(",", @pairs) . "}";
    }
    if (ref($val) eq "ARRAY") {
        my @items = ();
        foreach my $item (@{$val}) {
            push(@items, json_encode($item));
        }
        return "[" . join(",", @items) . "]";
    }
    # Number check (simple)
    if ($val =~ /^-?\d+(\.\d+)?$/) {
        return $val;
    }
    # String — escape quotes
    my $escaped = $val;
    $escaped =~ s/\\/\\\\/g;
    $escaped =~ s/"/\\"/g;
    $escaped =~ s/\n/\\n/g;
    $escaped =~ s/\t/\\t/g;
    return "\"" . $escaped . "\"";
}

# Test encoding
ok(json_encode(undef) eq "null", "encode null");
ok(json_encode(42) eq "42", "encode int");
ok(json_encode(3.14) eq "3.14", "encode float");
ok(json_encode("hello") eq "\"hello\"", "encode string");
ok(json_encode("say \"hi\"") eq "\"say \\\"hi\\\"\"", "encode escaped");

my $arr = [1, "two", 3];
ok(json_encode($arr) eq "[1,\"two\",3]", "encode array: " . json_encode($arr));

my $obj = { name => "Alice", age => 30 };
my $json = json_encode($obj);
ok($json eq "{\"age\":30,\"name\":\"Alice\"}", "encode object: " . $json);

# Nested
my $nested = {
    users => [
        { name => "Alice", active => 1 },
        { name => "Bob", active => 0 },
    ],
    count => 2,
};
my $nested_json = json_encode($nested);
ok(index($nested_json, "\"count\":2") >= 0, "nested has count");
ok(index($nested_json, "\"name\":\"Alice\"") >= 0, "nested has Alice");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All JSON tests passed!\n"; }
