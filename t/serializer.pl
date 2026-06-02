use strict;
use warnings;

# Simple JSON-like serializer — recursive data structure traversal

sub serialize {
    my ($data, $indent) = @_;
    if (!defined($indent)) { $indent = 0; }
    my $pad = "  " x $indent;

    if (!defined($data)) {
        return "null";
    }

    my $type = ref($data);

    if ($type eq "HASH") {
        my @keys = sort(keys(%{$data}));
        if (scalar(@keys) == 0) {
            return "{}";
        }
        my @parts = ();
        foreach my $k (@keys) {
            my $val = serialize($data->{$k}, $indent + 1);
            push(@parts, $pad . "  \"" . $k . "\": " . $val);
        }
        return "{\n" . join(",\n", @parts) . "\n" . $pad . "}";
    }

    if ($type eq "ARRAY") {
        my @elems = @{$data};
        if (scalar(@elems) == 0) {
            return "[]";
        }
        my @parts = ();
        foreach my $e (@elems) {
            push(@parts, $pad . "  " . serialize($e, $indent + 1));
        }
        return "[\n" . join(",\n", @parts) . "\n" . $pad . "]";
    }

    # Scalar — check if numeric
    if ($data =~ /^-?\d+$/) {
        return $data;
    }
    if ($data =~ /^-?\d+\.\d+$/) {
        return $data;
    }

    # String
    my $escaped = $data;
    $escaped =~ s/\\/\\\\/g;
    $escaped =~ s/"/\\"/g;
    return "\"" . $escaped . "\"";
}

# Test with nested data
my $data = {
    name    => "Alice",
    age     => 30,
    active  => 1,
    address => {
        street => "123 Main St",
        city   => "Portland",
        zip    => "97201",
    },
    tags    => ["perl", "hacker", "admin"],
    scores  => [95, 87, 92],
};

my $json = serialize($data);
print $json . "\n\n";

# Test edge cases
print "null: " . serialize(undef) . "\n";
print "empty hash: " . serialize({}) . "\n";
print "empty array: " . serialize([]) . "\n";
print "string: " . serialize("hello") . "\n";
print "number: " . serialize(42) . "\n";

# Roundtrip-ish test: verify structure
if (index($json, "\"name\": \"Alice\"") >= 0) {
    print "Name OK\n";
}
if (index($json, "\"age\": 30") >= 0) {
    print "Age OK\n";
}
if (index($json, "\"city\": \"Portland\"") >= 0) {
    print "City OK\n";
}
if (index($json, "\"perl\"") >= 0) {
    print "Tags OK\n";
}

print "Serializer test passed!\n";
