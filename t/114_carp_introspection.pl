#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Carp's croak/carp/confess/cluck are inline-codegen builtins; they are
# now ALSO registered as real Carp sub objects so introspection and
# indirect/method calls work, while direct `croak(...)` calls keep using
# the richer inline path.
use Carp qw(croak carp confess);

ok(defined &main::croak, 'croak promoted into caller (defined &main::croak)');
ok(defined &main::confess, 'confess promoted');
ok(main->can('croak'), 'main->can(croak)');
ok(Carp->can('croak'), 'Carp->can(croak)');
ok(defined &Carp::croak, 'defined &Carp::croak');

# Direct call uses the inline path.
eval { croak("direct boom") };
like($@, qr/direct boom/, 'direct croak sets $@');
like($@, qr/at .* line \d+/, 'direct croak appends location');

# Indirect call via coderef uses the registered sub.
my $cr = \&croak;
eval { $cr->("indirect boom") };
like($@, qr/indirect boom/, 'indirect croak via \&croak sets $@');

# confess via coderef.
my $cf = \&confess;
eval { $cf->("confess boom") };
like($@, qr/confess boom/, 'indirect confess sets $@');

# carp is registered too (introspectable), though its STDERR warning
# trace for indirect calls isn't byte-identical to perl's.
ok(defined &main::carp, 'carp promoted into caller');

done_testing;
