use strict;
use warnings;

# Test 1: forward goto
goto FORWARD;
die "should not reach (forward skip)";
FORWARD:

# Test 2: backward goto loop
my $i = 0;
LOOP:
$i++;
goto LOOP if $i < 5;
die "loop count wrong" unless $i == 5;

# Test 3: goto with postfix-if
my $taken = 0;
goto BRANCH_A if 1;
$taken = 999;  # unreached
die "if-skip failed" if $taken == 999;
BRANCH_A:

# Test 4: goto with postfix-unless
$taken = 0;
goto BRANCH_B unless 0;
$taken = 999;  # unreached
die "unless-skip failed" if $taken == 999;
BRANCH_B:

# Test 5: out of nested block
my $reached = 0;
{
    {
        goto OUT_NESTED;
    }
    $reached = 999;
}
OUT_NESTED:
die "nested goto failed" if $reached == 999;

# Test 6: goto from inside sub jumps out (we don't support cross-sub jumps,
# but in-sub forward/backward should work).
sub goto_in_sub {
    my $n = 0;
    SUBLOOP:
    $n++;
    goto SUBLOOP if $n < 3;
    return $n;
}
die "sub goto wrong" unless goto_in_sub() == 3;

# Test 7: multiple labels in a function
sub multi_label {
    my $stage = "start";
    A:
    $stage = "at-A";
    goto B;
    $stage = "wrong";  # skipped
    B:
    $stage .= "-B";
    return $stage;
}
die "multi label" unless multi_label() eq "at-A-B";

print "ok\n";
