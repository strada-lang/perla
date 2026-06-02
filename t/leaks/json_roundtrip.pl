# Leak: JSON encode/decode round-trip.
use JSON::PP;
for (my $i = 0; $i < 1000; $i++) {
    my $data = { id => $i, items => [1, 2, 3], name => "obj_$i" };
    my $j = encode_json($data);
    my $back = decode_json($j);
}
print "ok\n";
