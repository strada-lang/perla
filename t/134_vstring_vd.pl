#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# %v vector flag formats each CHARACTER's ordinal. For a SVf_UTF8 string the
# ordinals are codepoints, not bytes — chr(333) must print as 333, not as the
# byte 0xC5 (=197) that begins its UTF-8 encoding.
is(sprintf("%vd", chr(1) . chr(22) . chr(333)), "1.22.333", "%vd codepoints (utf8)");
is(sprintf("%vd", chr(1) . chr(2) . chr(3)),    "1.2.3",     "%vd codepoints (ascii)");

# Plain (non-utf8) byte string: each byte's ordinal.
is(sprintf("%vd", "ABC"), "65.66.67", "%vd bytes of ascii literal");

# Numeric-looking string is treated as a literal string, not a v-string.
is(sprintf("%vd", "1.22.333"),
   "49.46.50.50.46.51.51.51",
   "%vd of a plain string formats its bytes");

# Custom separator and hex spec.
is(sprintf("%v02x", chr(10) . chr(255) . chr(256)), "0a.ff.100", "%v02x hex codepoints");

# A wide codepoint round-trips through a higher value.
is(sprintf("%vd", chr(0x2603)), "9731", "%vd of a single wide char");

done_testing;
