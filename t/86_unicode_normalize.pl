#!/usr/bin/perl
use utf8;
use warnings;
use Test::More;
use Unicode::Normalize qw(NFC NFD NFKC NFKD normalize);

# Basic Latin-1 Supplement decomposition.
{
    my $orig = "café";  # 4 codepoints: c a f é
    is(length($orig), 4, 'starting codepoint count');
    my $nfd = NFD($orig);
    is(length($nfd), 5, 'NFD splits é into e + combining acute');
    my $nfc = NFC($nfd);
    is(length($nfc), 4, 'NFC recombines back');
    is($nfc, $orig, 'NFD → NFC round-trip is identity');
}

# Multiple diacritics on different bases (Latin Extended-A).
{
    my $orig = "naïve";          # ï = U+00EF
    my $nfd = NFD($orig);
    is(length($nfd), 6, 'naïve decomposes to 6 codepoints');
    my $nfc = NFC($nfd);
    is($nfc, $orig, 'naïve round-trip');
}

# Hangul algorithmic decomposition (no table needed).
{
    my $han = "\x{AC00}";        # 가 = U+AC00 (Hangul Syllable)
    my $nfd = NFD($han);
    is(length($nfd), 2, 'Hangul AC00 decomposes to L + V');
    is(ord(substr($nfd, 0, 1)), 0x1100, 'first decomposed char is ᄀ (L)');
    is(ord(substr($nfd, 1, 1)), 0x1161, 'second is ᅡ (V)');
    my $nfc = NFC($nfd);
    is($nfc, $han, 'Hangul round-trip via algorithmic comp');
}

# Hangul with trailing consonant (LVT form).
{
    my $hangul = "\x{AC01}";     # 각 = LVT
    my $nfd = NFD($hangul);
    is(length($nfd), 3, 'Hangul LVT decomposes to L + V + T');
    my $nfc = NFC($nfd);
    is($nfc, $hangul, 'Hangul LVT round-trip');
}

# normalize() with form string argument.
{
    my $orig = "à";
    is(length(normalize("NFD", $orig)), 2, 'normalize(NFD, ...) decomposes');
    is(length(normalize("NFC", normalize("NFD", $orig))), 1, 'normalize(NFC, ...) recombines');
}

# Pass-through for codepoints with no decomposition.
{
    my $ascii = "hello";
    is(NFD($ascii), $ascii, 'ASCII NFD is identity');
    is(NFC($ascii), $ascii, 'ASCII NFC is identity');
}

# Compatibility decomposition (NFKC / NFKD).
{
    is(NFKC("\x{FB01}"), "fi", 'NFKC unfolds ligature ﬁ → fi');
    is(NFKC("\x{00B2}"), "2",  'NFKC unfolds superscript ² → 2');
    is(NFKC("\x{FF21}"), "A",  'NFKC unfolds fullwidth A → A');
    is(NFKD("\x{FB01}"), "fi", 'NFKD unfolds ligature ﬁ → fi');
}

# Canonical reordering: combining marks of different classes must
# sort in ccc order regardless of source order. dot-below (220)
# precedes diaeresis (230) under canonical ordering.
{
    my $unordered = "a\x{0308}\x{0323}";  # a + diaeresis + dot-below
    my $nfd = NFD($unordered);
    is(length($nfd), 3, 'NFD on combined marks produces 3 codepoints');
    is(ord(substr($nfd, 1, 1)), 0x0323, 'dot-below (ccc 220) sorts first');
    is(ord(substr($nfd, 2, 1)), 0x0308, 'diaeresis (ccc 230) sorts second');
}

done_testing();
