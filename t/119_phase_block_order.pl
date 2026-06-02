#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Perl runs compile/init phase blocks in a defined order regardless of source
# position: BEGIN (source order) -> CHECK / UNITCHECK (reverse declaration
# order) -> INIT (source order) -> main body. perla used to lex INIT/CHECK as
# BEGIN and run them all in source order.

# Capture the phase order by appending to a file written by each block, then
# read it back in the main body. (Can't compare in-block since Test::More
# isn't loaded during BEGIN-time ordering checks reliably.)
our @order;
BEGIN { push @order, "B1" }
INIT  { push @order, "I1" }
CHECK { push @order, "C1" }
BEGIN { push @order, "B2" }
INIT  { push @order, "I2" }
CHECK { push @order, "C2" }

is(join(",", @order), "B1,B2,C2,C1,I1,I2",
   'phase order: BEGIN(src) -> CHECK(reverse) -> INIT(src)');

# A lone INIT still runs before main. (Declare without re-initialising in the
# main body — `our $x = ...` at main time would clobber the INIT's write.)
our $log;
INIT { $log = "init-" }
$log .= "main";
is($log, "init-main", 'INIT runs before main body');

done_testing;
