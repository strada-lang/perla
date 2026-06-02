#!/usr/bin/perl
use warnings;
use Test::More;

package Source;
our $var = "orig";

package main;
our $alias;
*alias = \$Source::var;

# Read-side alias: both names report the same initial value.
is($alias, "orig", '\$alias reads source value');
is($Source::var, "orig", '\$Source::var unchanged after alias setup');

# Write through target: source should see the new value.
$alias = "via_target";
is($Source::var, "via_target", '\$alias = X propagates to source');
is($alias, "via_target", '\$alias reflects its own write');

# Write through source: target should see the new value.
$Source::var = "via_source";
is($alias, "via_source", '\$source = X propagates to alias');
is($Source::var, "via_source", '\$source reflects its own write');

# Chained: B aliases to A; write through B → A AND any other alias of A.
our $b_alias;
*b_alias = \$Source::var;
$b_alias = "via_b";
is($Source::var, "via_b", 'second alias write reaches source');
is($alias, "via_b", 'second alias write reaches first alias (fan-out)');

done_testing();
