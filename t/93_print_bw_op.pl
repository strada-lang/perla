#!/usr/bin/perl
use warnings;
use Test::More;

# `printf NAME . "..."` where NAME is an uppercase bareword (typically a
# `use constant`) — the FH-shaped-bareword heuristic in _parse_primary
# saw `printf FORMAT` and treated FORMAT as a filehandle, eating the
# trailing concat + comma list. Without `OP` (and `FAT_ARROW`) in the
# next-token exclusion list, `printf FMT . "\n", "k", "v"` produced
# nothing — the constant got consumed as a FH and `. "\n"` started a
# fresh expression that printf never saw.

use constant FMT => "%-20s %s";
use constant FMT2 => "row=%s, val=%d";

{
    my $buf_a = "";
    open(my $fha, ">", \$buf_a) or die;
    printf {$fha} FMT . "\n", "k", "v";
    close $fha;
    is($buf_a, sprintf("%-20s %s\n", "k", "v"), "printf FMT . \"\\n\" routes the constant as format");
}

# Same shape for `print` (also a bareword-FH consumer)
{
    my $buf_b = "";
    open(my $fhb, ">", \$buf_b) or die;
    print {$fhb} FMT . "\n";
    close $fhb;
    is($buf_b, "%-20s %s\n", "print BW . \"\\n\" routes constant as content");
}

# Stash-resident constant subroutines (`use constant NAME => ...` installs
# a sub) — same fallthrough; without OP exclusion, the call drops args.
{
    my $buf_c = "";
    open(my $fhc, ">", \$buf_c) or die;
    printf {$fhc} FMT2 . "\n", "x", 42;
    close $fhc;
    is($buf_c, "row=x, val=42\n", "printf BW . \"...\" works with second constant");
}

done_testing;
