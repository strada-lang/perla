#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# sprintf("%c", N) treats N as a Unicode codepoint. For N >= 0x80 it emits
# the UTF-8 encoding AND flags the result SVf_UTF8, so length()/ord() see a
# single character — not the raw byte count.

is(length(sprintf("%c", 0x2603)), 1, '%c of U+2603 is one char (was 3 bytes)');

my $snow = sprintf("%c", 0x2603);
is(ord($snow), 0x2603, 'ord() recovers the codepoint');

is(length(sprintf("x%cy", 0x100)), 3, 'wide %c counted as one char among ASCII');

# ASCII %c is unaffected.
is(sprintf("[%c%c]", 65, 66), "[AB]", 'ASCII %c');
is(length(sprintf("%c", 65)), 1, 'ASCII %c length 1');

# Embedded NUL still survives (byte, not a wide char).
is(length(sprintf("a%cb", 0)), 3, '%c of 0 produces a NUL byte');

# uc() of a wide %c char round-trips (the symbol has no uppercase form).
is(uc($snow), $snow, 'uc() of a non-cased wide char is identity');

# Concatenating a wide %c keeps character semantics.
my $s = "ab" . sprintf("%c", 0x263A) . "cd";
is(length($s), 5, 'concat of wide %c keeps char count');

done_testing;
