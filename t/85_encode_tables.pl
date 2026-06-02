#!/usr/bin/perl
use utf8;
use warnings;
use Test::More;
use Encode;

# Latin1 round-trip: each codepoint 0-255 round-trips to a single byte.
{
    my $unicode = "café";  # 4 codepoints
    is(length($unicode), 4, 'unicode length is codepoints');
    my $bytes = encode("Latin1", $unicode);
    is(do { use bytes; length($bytes) }, 4, 'Latin1 encoded length matches codepoint count');
    is(ord(substr($bytes, 3, 1)), 0xE9, 'é encoded as 0xE9 byte');
    my $back = decode("Latin1", $bytes);
    is(length($back), 4, 'Latin1 decoded back to 4 codepoints');
    is($back, $unicode, 'Latin1 round-trip is identity');
}

# CP1252-specific: € (U+20AC) maps to 0x80.
{
    my $unicode = "€";
    is(length($unicode), 1, 'euro is a single codepoint');
    my $bytes = encode("CP1252", $unicode);
    is(do { use bytes; length($bytes) }, 1, 'CP1252 encodes € to single byte');
    is(ord(substr($bytes, 0, 1)), 0x80, '€ encoded as 0x80 in CP1252');
    my $back = decode("CP1252", $bytes);
    is(ord(substr($back, 0, 1)), 0x20AC, '0x80 decodes back to U+20AC under CP1252');
}

# ASCII drops high-byte chars to `?`.
{
    my $unicode = "À";  # U+00C0
    my $bytes = encode("ASCII", $unicode);
    is($bytes, "?", 'non-ASCII codepoint folds to ? under ASCII encode');
}

# UTF-8 round-trip (the existing behaviour).
{
    my $unicode = "→";  # U+2192
    is(length($unicode), 1, 'arrow is one codepoint');
    my $bytes = encode("UTF-8", $unicode);
    is(do { use bytes; length($bytes) }, 3, 'arrow is 3 bytes in UTF-8');
    my $back = decode("UTF-8", $bytes);
    is(length($back), 1, 'UTF-8 round-trip preserves codepoint count');
    is($back, $unicode, 'UTF-8 round-trip is identity');
}

# CP1251 (Cyrillic) round-trip.
{
    my $rus = "Россия";
    my $bytes = encode("cp1251", $rus);
    is(do { use bytes; length($bytes) }, 6, 'CP1251 encodes Cyrillic to 1 byte/char');
    is(ord(substr($bytes, 1, 1)), 0xEE, 'CP1251: о (U+043E) maps to 0xEE');
    is(decode("cp1251", $bytes), $rus, 'CP1251 round-trip');
}

# CP1250 (Central European) round-trip.
{
    my $czech = "Příliš";  # Czech chars (ř U+0159, í U+00ED, š U+0161)
    my $bytes = encode("cp1250", $czech);
    is(decode("cp1250", $bytes), $czech, 'CP1250 round-trip');
}

# CP1253 (Greek) round-trip.
{
    my $greek = "Αθήνα";
    my $bytes = encode("cp1253", $greek);
    is(decode("cp1253", $bytes), $greek, 'CP1253 round-trip');
}

done_testing();
