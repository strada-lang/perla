use strict;
use warnings;

# vec(EXPR, OFFSET, BITS) — bit-vector accessor.
# Sub-byte fields are LSB-first within each byte (perl semantics).
# Multi-byte fields are big-endian.

# 8-bit
my $bytes = "";
vec($bytes, 0, 8) = 65;  # 'A'
vec($bytes, 1, 8) = 66;  # 'B'
vec($bytes, 2, 8) = 67;  # 'C'
die "8-bit set" unless $bytes eq "ABC";
die "8-bit get [0]" unless vec($bytes, 0, 8) == 65;
die "8-bit get [2]" unless vec($bytes, 2, 8) == 67;

# 16-bit (big-endian)
my $w = "";
vec($w, 0, 16) = 0x4142;
vec($w, 1, 16) = 0x4344;
my @ws = unpack("C*", $w);
die "16-bit byte 0" unless $ws[0] == 0x41;
die "16-bit byte 1" unless $ws[1] == 0x42;
die "16-bit get" unless vec($w, 1, 16) == 0x4344;

# 1-bit (LSB-first)
my $b = "";
vec($b, 0, 1) = 1;
vec($b, 3, 1) = 1;
vec($b, 7, 1) = 1;
die "1-bit pack: got " . ord($b) unless ord($b) == 0x89;  # 10001001
die "1-bit get [0]" unless vec($b, 0, 1) == 1;
die "1-bit get [1]" unless vec($b, 1, 1) == 0;
die "1-bit get [3]" unless vec($b, 3, 1) == 1;
die "1-bit get [7]" unless vec($b, 7, 1) == 1;

# 4-bit nibbles
my $n = "";
vec($n, 0, 4) = 0xA;
vec($n, 1, 4) = 0xB;
die "4-bit pack: got " . sprintf("%02x", ord($n)) unless ord($n) == 0xBA;
die "4-bit get [0]" unless vec($n, 0, 4) == 0xA;
die "4-bit get [1]" unless vec($n, 1, 4) == 0xB;

# Auto-extend
my $g = "";
vec($g, 5, 8) = 99;
die "extend len" unless length($g) == 6;
die "extend [0]" unless vec($g, 0, 8) == 0;
die "extend [5]" unless vec($g, 5, 8) == 99;

# 32-bit
my $l = "";
vec($l, 0, 32) = 0x12345678;
die "32-bit get" unless vec($l, 0, 32) == 0x12345678;
die "32-bit byte" unless ord(substr($l, 0, 1)) == 0x12;

print "ok\n";
