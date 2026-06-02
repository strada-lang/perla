use strict;
use warnings;

# Scalar::Util::readonly — compile-time literal detection
use Scalar::Util qw(readonly);
my $v = 42;
die "var ro" if readonly($v);
die "literal int" unless readonly(42);
die "literal str" unless readonly("hello");
die "literal num" unless readonly(3.14);

# pack/unpack n/A* length-prefix format
my $packed = pack("n/A*", "hello");
die "pack n/A*: " . unpack("H*", $packed) unless unpack("H*", $packed) eq "000568656c6c6f";
my @r = unpack("n/A*", $packed);
die "unpack n/A*: $r[0]" unless $r[0] eq "hello";

# Round-trip with multiple
my $multi = pack("n/A* n/A*", "foo", "bar");
my @r2 = unpack("n/A* n/A*", $multi);
die "multi: $r2[0] $r2[1]" unless $r2[0] eq "foo" && $r2[1] eq "bar";

# N (4-byte) length prefix
my $big = pack("N/A*", "x" x 256);
my @rb = unpack("N/A*", $big);
die "N/A* big" unless $rb[0] eq "x" x 256;

# C (1-byte) length prefix
my $small = pack("C/A*", "hi");
die "C/A* hex" unless unpack("H*", $small) eq "026869";
my @rs = unpack("C/A*", $small);
die "C/A* unpack: $rs[0]" unless $rs[0] eq "hi";

print "ok\n";
