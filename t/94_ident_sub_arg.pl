#!/usr/bin/perl
use warnings;
use Test::More;

# `IDENT sub { ... }` (no parens, anon sub as the first arg) — perl
# parses it as `IDENT(sub { ... })`. perla's parser's bare-IDENT
# no-paren call branch only consumed certain follow-up token types
# (SCALAR_VAR/ARRAY_VAR/STRING/INT/...) as first arg — but NOT SUB.
# So `take_sub sub { 20 }` parsed as `take_sub()` plus a dropped
# `sub { 20 }` sibling expression. Mojo-/Catalyst-style DSL idioms
# (`get '/path' => sub { ... }`, `use_mw sub { ... }`, fluent
# middleware push) all hit this.

sub take_sub { $_[0]->() + 1 }
{
    my $r1 = take_sub(sub { 10 });
    is($r1, 11, "take_sub(sub {...}) parens form");
    my $r2 = take_sub sub { 20 };
    is($r2, 21, "take_sub sub {...} no parens form");
}

# Mojo-/Plack-style route registration. Forward-declare so perl
# accepts the bareword call shape.
sub get;
sub post;

my %routes;
sub get  { my ($p, $h) = @_; $routes{GET}{$p}  = $h }
sub post { my ($p, $h) = @_; $routes{POST}{$p} = $h }

get  '/'      => sub { "home" };
get  '/users' => sub { "users" };
post '/login' => sub { "login" };

is($routes{GET}{"/"}->(),       "home",  "get '/'  => sub {...}");
is($routes{GET}{"/users"}->(),  "users", "get '/users' => sub {...}");
is($routes{POST}{"/login"}->(), "login", "post '/login' => sub {...}");

# Middleware push pattern
sub use_mw;
my @mw;
sub use_mw { push @mw, shift }
use_mw sub { my $r = shift; $r->{a} = "A"; $r };
use_mw sub { my $r = shift; $r->{b} = "B"; $r };
my $req = { x => 1 };
$req = $_->($req) for @mw;
is($req->{a}, "A", "first middleware ran with bound \$r");
is($req->{b}, "B", "second middleware ran");
is($req->{x}, 1,   "original key preserved");

done_testing;
