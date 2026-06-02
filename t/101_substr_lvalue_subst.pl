#!/usr/bin/perl
use warnings;
use Test::More;

# `substr(STR, OFF, LEN) =~ s///` — substr-lvalue + regex substitution
# is a perl idiom that modifies STR in place through the lvalue
# alias returned by substr(). perla's gen_expr on N_CALL("substr")
# returns a rvalue copy, so the s/// silently applies to a temp
# and STR stays unchanged. File::Temp::_replace_XX uses
# `substr($path, 0, -$ignore) =~ s/X(?=X*\z)/.../ge` to substitute
# the XXX placeholder — without this fix, every File::Temp call
# returned the same template filename and the second call died
# with "File exists".

# Plain substr range
{
    my $s = "abcXdef";
    substr($s, 0, 4) =~ s/X/Y/;
    is($s, "abcYdef", "substr(\$s, 0, 4) =~ s/X/Y/ modifies \$s in place");
}

# Negative-length substr (replace span ends at -N from end). Without
# the runtime fix to strada_substr_assign, negative length was
# clamped to 0 and the writeback inserted instead of replacing.
{
    my $s = "/tmp/XXXXXXXXXX.dat";
    substr($s, 0, -4) =~ s/X(?=X*\z)/A/g;
    is($s, "/tmp/AAAAAAAAAA.dat",
        "substr with negative length replaces up to -N from end");
}

# Multiple substitutions accumulate
{
    my $s = "hello world";
    substr($s, 0, 5) =~ s/l/L/g;
    is($s, "heLLo world", "/g on substr lvalue replaces all in span");
}

# Negative offset
{
    my $s = "abc123def";
    substr($s, -6, 3) =~ s/\d/X/g;
    is($s, "abcXXXdef", "negative offset works with s///");
}

# /e flag — replacement is code
{
    my $s = "aaaa.dat";
    substr($s, 0, -4) =~ s/a/uc($&)/ge;
    is($s, "AAAA.dat", "/e flag on substr lvalue works");
}

# File::Temp's actual idiom — _replace_XX template
{
    my @CHARS = ('A'..'Z', 'a'..'z', 0..9);
    my $tpl = "/tmp/XXXXXXXXXX.dat";
    my $end = "\\z";
    my $ignore = length(".dat");
    substr($tpl, 0, -$ignore) =~ s/X(?=X*$end)/$CHARS[ int( rand( @CHARS ) ) ]/ge;
    unlike($tpl, qr/^\/tmp\/XX/,  "File::Temp idiom replaces the X's");
    like($tpl, qr/\.dat$/,        "suffix preserved");
}


# `substr() =~ tr///` — same in-place modification semantics as s///.
{
    my $s = "abcdef";
    substr($s, 0, 3) =~ tr/a-z/A-Z/;
    is($s, "ABCdef", "substr =~ tr/a-z/A-Z/ uppercases in place");
}

{
    my $s = "hello world";
    substr($s, 6) =~ tr/a-z/A-Z/;
    is($s, "hello WORLD", "substr starting from 6 affects only second half");
}

# tr with /d flag (delete)
{
    my $s = "abc123def";
    substr($s, 0, 6) =~ tr/0-9//d;
    is($s, "abcdef", "tr/0-9//d on substr deletes digits in span");
}

done_testing;
