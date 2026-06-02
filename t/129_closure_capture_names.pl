#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Regression: closures must capture lexicals named $pass / $fail. The free-var
# analysis used to exclude the names "pass"/"fail" (aimed at Test::More's
# pass()/fail() barewords, which never enter the used-var set) and so dropped
# the *scalars* $pass/$fail from closure capture — they read as undef inside
# the closure. This silently lost the password in DBI.pm's connect closure
# (`$drh->connect($dsn, $user, $pass, $attr)`), breaking DB auth.

sub make_closure {
    my ($pass, $fail) = @_;
    return sub { return "$pass|$fail" };
}
is(make_closure("secret", "nope")->(), "secret|nope",
   'closure captures lexicals named $pass and $fail');

# deeper: param conditionally touched, then captured (the DBI.pm shape)
sub dbi_like {
    my ($class, $dsn, $user, $pass, $attr) = @_;
    $pass = $attr->{Password} if defined $attr->{Password};
    my $c = sub { "$user/$pass" };
    return $c->();
}
is(dbi_like("DBI", "dsn", "alice", "s3cret", {}), "alice/s3cret",
   '5-arg sub: closure keeps $pass through a conditional reassign');

# Test::More pass()/fail() barewords are unaffected by the fix.
pass("pass() bareword still works");

done_testing;
