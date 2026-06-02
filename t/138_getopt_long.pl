#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native Getopt::Long (common subset): linkage + hashref modes, =s/=i/=f,
# flags, ! negation, + incremental, @/% destinations, aliases, --opt=val,
# --opt val, -o val, -- terminator, leftover @ARGV permutation.
use Getopt::Long qw(GetOptions GetOptionsFromArray);

# --- linkage mode, scalar refs ---
{
    my ($name, $verbose, $num);
    local @ARGV = ('--name=bob', '--verbose', '--num', '42', 'leftover');
    my $ok = GetOptions('name=s' => \$name, 'verbose' => \$verbose, 'num=i' => \$num);
    ok($ok, "GetOptions returns true");
    is($name, "bob", "string =s");
    is($verbose, 1, "boolean flag");
    is($num, 42, "integer =i");
    is("@ARGV", "leftover", "non-option left in \@ARGV");
}

# --- hashref mode ---
{
    my %o;
    local @ARGV = ('--name=al', '-v', '--num', '7');
    GetOptions(\%o, 'name=s', 'verbose|v', 'num=i');
    is($o{name}, "al", "hashref =s");
    is($o{verbose}, 1, "hashref flag via alias -v");
    is($o{num}, 7, "hashref =i");
}

# --- aliases, float, optional, -- terminator ---
{
    my %o;
    local @ARGV = ('--rate=2.5', '--', '--notanopt');
    GetOptions(\%o, 'rate|r=f');
    is($o{rate}, 2.5, "float =f via long alias");
    is("@ARGV", "--notanopt", "-- stops option parsing");
}

# --- negation ! and incremental + ---
{
    my %o;
    local @ARGV = ('--no-color', '-v', '-v', '-v');
    GetOptions(\%o, 'color!', 'verbose|v+');
    is($o{color}, 0, "--no-color sets 0");
    is($o{verbose}, 3, "incremental + counts");
}

# --- array destination (spec @ and ref-driven) ---
{
    my @inc;
    local @ARGV = ('-I', '/a', '-I', '/b');
    GetOptions('include|I=s' => \@inc);
    is("@inc", "/a /b", "array linkage accumulates (ref-type driven)");

    my %o2;
    local @ARGV = ('--lib=x', '--lib=y');
    GetOptions(\%o2, 'lib=s@');
    is("@{$o2{lib}}", "x y", "hashref =s\@ accumulates");
}

# --- hash destination % ---
{
    my %o;
    local @ARGV = ('--def', 'a=1', '--def', 'b=2');
    GetOptions(\%o, 'def=s%');
    is($o{def}{a}, "1", "hash dest key a");
    is($o{def}{b}, "2", "hash dest key b");
}

# --- GetOptionsFromArray ---
{
    my %o; my @args = ('--foo=9', 'rest');
    GetOptionsFromArray(\@args, \%o, 'foo=i');
    is($o{foo}, 9, "GetOptionsFromArray =i");
    is("@args", "rest", "GetOptionsFromArray leaves leftovers");
}

# --- Configure is a no-op that doesn't break ---
{
    Getopt::Long::Configure("bundling", "no_ignore_case");
    my %o; local @ARGV = ('--x=1');
    GetOptions(\%o, 'x=i');
    is($o{x}, 1, "Configure no-op, parsing still works");
}

done_testing;
