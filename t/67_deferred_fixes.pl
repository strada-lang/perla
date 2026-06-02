#!/usr/bin/env perl
use strict;

print "1..6\n";

# Multi-key hash subscript uses runtime $;
{
    my %h;
    $h{"a","b"} = 42;
    my $v = $h{"a","b"};
    print $v == 42 ? "ok 1 - multi-key subscript default \$;\n"
                   : "not ok 1 (got '$v')\n";
}

# $; respected at runtime (skip `local` — separate issue)
{
    $; = "|";
    my %h;
    $h{"x","y"} = 99;
    my $direct = $h{"x|y"};
    $; = "\x1C";  # restore default for next test
    print $direct == 99 ? "ok 2 - multi-key honours runtime \$;\n"
                        : "not ok 2 (got '$direct')\n";
}

# ${\ EXPR } in s/// replacement
{
    my $s = "hello world";
    (my $r = $s) =~ s/(\w+)/${\ uc($1)}/g;
    print $r eq "HELLO WORLD" ? "ok 3 - \${\\ EXPR} in s/// works\n"
                              : "not ok 3 (got '$r')\n";
}

# Monkey-patching basic case
{
    package Mock;
    sub new { bless {}, shift }
    sub greet { "default" }
    package main;
    my $obj = Mock->new;
    print $obj->greet eq "default" ? "ok 4 - method before patch\n"
                                   : "not ok 4 (got '" . $obj->greet . "')\n";
    no warnings 'redefine';
    *Mock::greet = sub { "patched" };
    print $obj->greet eq "patched" ? "ok 5 - method after monkey-patch\n"
                                   : "not ok 5 (got '" . $obj->greet . "')\n";
}

# Mock pattern with call tracking
{
    package Mock2;
    sub new { bless {}, shift }
    sub do_thing { 1 }
    package main;
    my $obj = Mock2->new;
    my @calls;
    no warnings 'redefine';
    *Mock2::do_thing = sub { push @calls, [@_]; "mocked" };
    $obj->do_thing("arg1", 2);
    $obj->do_thing("arg3");
    print (scalar(@calls) == 2 && $calls[0][1] eq "arg1" && $calls[1][1] eq "arg3"
        ? "ok 6 - mocked sub captures calls\n"
        : "not ok 6\n");
}
