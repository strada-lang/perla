#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native compression formats (libz; bzip2 via dlopen libbz2):
#   Compress::Zlib      compress/uncompress, memGzip/memGunzip, adler32, crc32
#   IO::Compress::Deflate / Inflate        (zlib  RFC1950)
#   IO::Compress::RawDeflate / RawInflate  (raw   RFC1951)
#   IO::Compress::Bzip2 / Bunzip2          (bzip2)
use Compress::Zlib;
use IO::Compress::Deflate qw(deflate);
use IO::Uncompress::Inflate qw(inflate);
use IO::Compress::RawDeflate qw(rawdeflate);
use IO::Uncompress::RawInflate qw(rawinflate);
use IO::Compress::Bzip2 qw(bzip2);
use IO::Uncompress::Bunzip2 qw(bunzip2);

my $data = "The quick brown fox jumps over the lazy dog.\n" x 7;

# Compress::Zlib compress/uncompress (zlib RFC1950)
my $z = compress($data);
ok(length($z) > 0 && length($z) < length($data), "compress shrinks");
is(uncompress($z), $data, "compress/uncompress round-trips");

# memGzip/memGunzip (gzip)
my $g = memGzip($data);
is(substr($g, 0, 2), "\x1f\x8b", "memGzip emits gzip magic");
is(memGunzip($g), $data, "memGzip/memGunzip round-trips");

# checksums against the standard "123456789" vectors
is(crc32("123456789"),   3421780262, "crc32 standard vector");
is(adler32("123456789"), 152961502,  "adler32 standard vector");

# IO::Compress::Deflate (zlib) round-trip
my ($d, $di); deflate(\$data => \$d); inflate(\$d => \$di);
is($di, $data, "deflate/inflate (zlib) round-trips");

# RawDeflate (headerless) round-trip
my ($r, $ri); rawdeflate(\$data => \$r); rawinflate(\$r => \$ri);
is($ri, $data, "rawdeflate/rawinflate round-trips");

# Bzip2 (skips if libbz2 isn't loadable)
my $b; bzip2(\$data => \$b);
if (defined $b && length $b) {
    is(substr($b, 0, 2), "BZ", "bzip2 emits BZ magic");
    my $bi; bunzip2(\$b => \$bi);
    is($bi, $data, "bzip2/bunzip2 round-trips");
} else {
    SKIP: { skip "libbz2 not available", 2; }
}

done_testing;
