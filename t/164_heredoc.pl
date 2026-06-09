#!/usr/bin/perl
use strict;
use warnings;

# Comprehensive heredoc lexing coverage. Exits non-zero (die) on any mismatch
# so t/run_tests.sh flags a regression. Added as the safety net for the L6
# heredoc-lexing change (replace per-heredoc whole-source re-splice with
# O(1) skip ranges). Covers every form the lexer special-cases.

my $fails = 0;
sub check {
    my ($got, $want, $label) = @_;
    if (!defined($got)) { $got = "<undef>"; }
    if ($got ne $want) {
        print "FAIL: $label\n  got : [$got]\n  want: [$want]\n";
        $fails++;
    }
}

# 1. Basic interpolated bareword heredoc.
my $a = <<END;
line one
line two
END
check($a, "line one\nline two\n", "basic <<END");

# 2. Raw single-quoted heredoc: NO interpolation.
my $name = "world";
my $raw = <<'EOT';
hello $name
EOT
check($raw, 'hello $name' . "\n", "raw <<'EOT' no interp");

# 3. Double-quoted heredoc: DOES interpolate.
my $dq = <<"EOT";
hello $name
EOT
check($dq, "hello world\n", 'double-quoted <<"EOT" interpolates');

# 4. Variable interpolation in bareword heredoc.
my $n = 42;
my $interp = <<END;
n is $n
END
check($interp, "n is 42\n", "interpolation in <<END");

# 5. Indented heredoc <<~ strips common leading whitespace.
my $ind = <<~END;
        indented a
          indented b
        END
check($ind, "indented a\n  indented b\n", "<<~END indent strip");

# 6. MULTIPLE heredocs on one line — body A then body B (the case the splice
#    made work; the skip-range fix must preserve it).
my @parts;
push @parts, <<A, <<B;
first body
A
second body
B
check($parts[0], "first body\n", "multi heredoc body A");
check($parts[1], "second body\n", "multi heredoc body B");

# 7. Heredoc as a mid-expression function argument: the rest of the line
#    (", $x )") must still be tokenized.
sub joiner { my ($h, $x) = @_; return $h . "[$x]"; }
my $z = 7;
my $mid = joiner(<<END, $z);
body text
END
check($mid, "body text\n[7]", "heredoc mid-expression arg");

# 8. Body containing code-like text (braces, semicolons, a non-closing line
#    that merely contains the delimiter) must be treated as literal text.
my $code = <<'EOC';
sub foo { return 1; }
not EOC really
EOC
check($code, "sub foo { return 1; }\nnot EOC really\n", "code-like heredoc body");

# 9. Empty heredoc.
my $empty = <<END;
END
check($empty, "", "empty heredoc");

# 10. Code AFTER the heredoc on later lines runs correctly.
my $before = "B";
my $h10 = <<END;
ten
END
my $after = "A";
check($before . $after, "BA", "statements around heredoc execute");
check($h10, "ten\n", "heredoc value with surrounding code");

# 11. Consecutive heredocs on separate statements/lines.
my $h11a = <<X;
aaa
X
my $h11b = <<Y;
bbb
Y
check($h11a . $h11b, "aaa\nbbb\n", "consecutive heredocs on separate lines");

# 12. Heredoc whose body has blank lines.
my $blank = <<END;
top

bottom
END
check($blank, "top\n\nbottom\n", "heredoc with blank line in body");

# 13. Heredoc concatenated between two strings on the same line: the trailing
#     ` . "xyz"` (read by the string scanner, which uses lx{src}/lx{len}) must
#     still tokenize correctly with the body NOT spliced out.
my $cat = "abc" . <<END . "xyz";
mid
END
check($cat, "abcmid\nxyz", "string . heredoc . string on one line");

# 14. Three heredocs on one line.
my ($p, $q, $r);
($p, $q, $r) = (<<P, <<Q, <<R);
pp
P
qq
Q
rr
R
check("$p$q$r", "pp\nqq\nrr\n", "three heredocs on one line");

if ($fails) { die "$fails heredoc check(s) failed\n"; }
print "all heredoc checks passed\n";
