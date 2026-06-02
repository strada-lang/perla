#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native zlib-backed IO::Compress::Gzip / IO::Uncompress::Gunzip.
# gzip/gunzip take ($src => $dst) where each is a scalar-ref (in-memory) or a
# filename. Assert round-trips and gzip-stream validity (not exact compressed
# size, which depends on the zlib level/strategy).
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# --- in-memory round trip ---
my $text = "the quick brown fox\n" x 8;
my $gz;
ok(gzip(\$text => \$gz), 'gzip(\$in => \$out) returns true');
ok(length($gz) > 0, 'compressed output is non-empty');
is(substr($gz, 0, 2), "\x1f\x8b", 'output has the gzip magic bytes');
my $back;
ok(gunzip(\$gz => \$back), 'gunzip(\$in => \$out) returns true');
is($back, $text, 'in-memory gzip/gunzip round-trips');

# --- binary data with NUL bytes ---
my $bin = join('', map { chr($_ % 256) } 0 .. 999);
my ($bg, $bb);
gzip(\$bin => \$bg) or die "gzip binary: $GzipError";
gunzip(\$bg => \$bb) or die "gunzip binary: $GunzipError";
is($bb, $bin, 'binary (with NUL) round-trips');

# --- filename forms ---
my $tmp = "/tmp/perla_t124_$$.gz";
ok(gzip(\$text => $tmp), 'gzip to a filename');
my $fback;
ok(gunzip($tmp => \$fback), 'gunzip from a filename');
is($fback, $text, 'file gzip/gunzip round-trips');

# --- interop: decompress a stream produced by the system gzip ---
my $sysgz = "/tmp/perla_t124_sys_$$.gz";
system(qq{printf 'interop\\n' | gzip > $sysgz});
my $sysout;
if (gunzip($sysgz => \$sysout)) {
    is($sysout, "interop\n", 'decompresses a system-gzip stream');
} else {
    fail('decompresses a system-gzip stream');
}

# --- empty input ---
my ($eg, $eb);
gzip(\(my $empty = "") => \$eg);
gunzip(\$eg => \$eb);
is($eb, "", 'empty input round-trips to empty');

unlink $tmp, $sysgz;
done_testing;
