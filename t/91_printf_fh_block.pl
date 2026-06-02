#!/usr/bin/perl
use warnings;
use Test::More;

# `printf {EXPR} FMT, ARGS` — the block-FH form. The historical
# parser's IDENT-LBRACE-LIST fallback (which wraps the block as an
# anon-sub coderef for `(&@)`-prototype builtins) excluded
# `print`/`say`/`die`/`warn` but forgot `printf`. So `printf {$fh}
# "fmt", args` parsed as `printf(sub {$fh}, "fmt", args)` and the
# format string ended up as printf's second arg, with a CODE ref
# prepended to STDOUT. Fix in `_parse_primary`: add `printf` to the
# exclusion list so the `print/say/die/warn/printf` block-FH branch
# runs instead.

# In-memory FH
{
    my $buf_a = "";
    open(my $fh_a, ">", \$buf_a) or die;
    printf {$fh_a} "x=%d y=%d\n", 1, 2;
    close $fh_a;
    is($buf_a, "x=1 y=2\n", "printf {\$fh} writes to scalar-ref FH");
}

# Multiple printf to same FH
{
    my $buf_b = "";
    open(my $fh_b, ">", \$buf_b) or die;
    printf {$fh_b} "%s ", "hello";
    printf {$fh_b} "%s\n", "world";
    close $fh_b;
    is($buf_b, "hello world\n", "multiple printf {\$fh} accumulate");
}

# print {$fh} keeps working (regression check)
{
    my $buf_c = "";
    open(my $fh_c, ">", \$buf_c) or die;
    print {$fh_c} "raw\n";
    close $fh_c;
    is($buf_c, "raw\n", "print {\$fh} still works");
}

done_testing;
