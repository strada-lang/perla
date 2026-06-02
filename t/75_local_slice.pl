use strict;
use warnings;

# `local @h{KEYS} = VALS` — save+restore N hash entries for the duration
# of the enclosing scope.
our %g = (a=>1, b=>2, c=>3, d=>4);
sub inner_h { return "$g{a},$g{b},$g{c},$g{d}" }
sub outer_h {
    local @g{qw(a c)} = (10, 30);
    return inner_h();
}
die "hash slice inside: got '" . outer_h() . "'" unless outer_h() eq "10,2,30,4";
die "hash slice after: got '" . inner_h() . "'" unless inner_h() eq "1,2,3,4";

# `local @arr[INDICES] = VALS` — same for arrays.
our @ar = (10, 20, 30, 40, 50);
sub inner_a { return join(",", @ar) }
sub outer_a {
    local @ar[1, 3] = (99, 88);
    return inner_a();
}
die "array slice inside: got '" . outer_a() . "'" unless outer_a() eq "10,99,30,88,50";
die "array slice after: got '" . inner_a() . "'" unless inner_a() eq "10,20,30,40,50";

# Range syntax in indices.
sub outer_range {
    local @ar[1..3] = (100, 200, 300);
    return inner_a();
}
die "array range inside: got '" . outer_range() . "'" unless outer_range() eq "10,100,200,300,50";
die "array range after: got '" . inner_a() . "'" unless inner_a() eq "10,20,30,40,50";

# Asymmetric (fewer values than keys → trailing keys get undef).
sub outer_short {
    local @g{qw(a b c)} = (99);
    return defined($g{a}) && !defined($g{b}) && !defined($g{c}) ? "ok" : "fail";
}
die "asymmetric: got '" . outer_short() . "'" unless outer_short() eq "ok";
# After scope exit, original values restored.
die "asymmetric after: a=$g{a} b=$g{b} c=$g{c}" unless $g{a} == 1 && $g{b} == 2 && $g{c} == 3;

# die during local — restoration still happens (local-chain in eval block).
our @logs;
sub maybe_die {
    local @ar[0, 4] = (-1, -1);
    push @logs, "before die: " . join(",", @ar);
    die "boom\n";
}
eval { maybe_die() };
die "post-eval @ar: " . join(",", @ar) unless join(",", @ar) eq "10,20,30,40,50";

print "ok\n";
