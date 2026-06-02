#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# POSIX::strftime normalizes the struct tm like Perl's mini_mktime: it
# ALWAYS recomputes the weekday (%A/%a/%w) and day-of-year (%j) from
# year/mon/mday — ignoring any supplied wday/yday — and normalizes
# out-of-range fields. perla used to trust the input wday (default 0 =
# Sunday) and not normalize overflow.
use POSIX qw(strftime);

# 2024-01-15 is a Monday. Supply a WRONG wday=0/yday=0; must be recomputed.
my @mon = (0, 30, 14, 15, 0, 124, 0, 0, 0);
is(strftime("%A", @mon), "Monday",   "%A recomputed from date, ignoring wrong wday");
is(strftime("%a", @mon), "Mon",      "%a recomputed");
is(strftime("%w", @mon), "1",        "%w recomputed");
is(strftime("%j", @mon), "015",      "%j recomputed from date, ignoring wrong yday");
is(strftime("%Y-%m-%d", @mon), "2024-01-15", "date fields intact");

# 2024-01-14 is a Sunday; supply wrong wday=3.
my @sun = (0, 0, 0, 14, 0, 124, 3, 99, 0);
is(strftime("%A %w %j", @sun), "Sunday 0 014", "wrong wday/yday overridden");

# out-of-range mday=32 in January normalizes to Feb 1 (a Thursday in 2024).
is(strftime("%Y-%m-%d %A", 0,0,0,32,0,124,0,0,0), "2024-02-01 Thursday",
   "mday overflow normalized");

# leap day 2024-02-29 is a Thursday
is(strftime("%A %Y-%m-%d", 0,0,0,29,1,124,0,0,0), "Thursday 2024-02-29",
   "leap day weekday correct");

# Real usage: gmtime() output already has correct wday/yday — stays correct.
my @g = gmtime(1700000000);   # 2023-11-14 (Tuesday) UTC
is(strftime("%Y-%m-%d %A %j", @g), "2023-11-14 Tuesday 318",
   "gmtime output formats correctly (normalization idempotent)");

# plain time fields unaffected
is(strftime("%H:%M:%S", 5, 4, 13, 1, 0, 124, 0, 0, 0), "13:04:05", "time fields intact");

done_testing;
