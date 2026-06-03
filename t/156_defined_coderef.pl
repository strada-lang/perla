#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# `defined &$coderef` must be true for a real code reference, whether the
# referent is a COMPILED named sub (perla represents `\&Pkg::sub` as a raw
# C-function-pointer / CPOINTER) or an anon/closure sub. perla previously
# treated the `defined &$var` introspection form purely as a by-name stash
# probe: it stringified the coderef to "CODE(0x..)", looked that up, found
# nothing, and reported undefined. This broke Moose::Exporter's
# _sub_from_package (`my $s = \&{"P::n"}; return $s if defined &$s`), which
# mis-reported every Moose::Util::TypeConstraints sugar sub (type, subtype,
# as, where, coerce, enum, ...) as undefined and refused to export them.

package Foo;
sub bar { 42 }
sub as { +{ as => shift } }
sub where (&) { +{ where => $_[0] } }
package main;

# --- reference to a compiled named sub (CPOINTER) ---
my $direct = \&Foo::bar;
ok(defined &$direct, 'defined &\$coderef true for \\&named_sub');
is($direct->(), 42, 'the coderef still calls correctly');

# --- via a symbolic name string: \&{ "Foo::bar" } ---
my $name = "Foo::bar";
my $sym = do { no strict 'refs'; \&{ $name }; };
ok(defined &$sym, 'defined &\$s true for \\&{ name-string }');

# --- inline symbolic form still works (by-name stash probe) ---
ok(defined &{ $name }, 'defined &{ name-string } true (inline)');

# --- prototyped + list-returning sugar subs (the TypeConstraints shapes) ---
my $as = \&Foo::as;
ok(defined &$as, 'defined true for list-returning sugar sub');
my $where = \&Foo::where;
ok(defined &$where, 'defined true for (&)-prototyped sub');

# --- a name that is NOT a defined sub must report undefined ---
my $missing = "Foo::nonexistent_xyz";
ok(!(defined &{ $missing }), 'defined &{ unknown-name } is false');

# --- anon closure coderef ---
my $anon = sub { 7 };
ok(defined &$anon, 'defined &\$anon_closure true');

done_testing;
