#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native DBD::Pg (libpq via dlopen). Needs a running PostgreSQL server, so it
# SKIPS when none is reachable (CI / boxes without postgres). Point it at a
# server with PERLA_TEST_PG_DSN (+ _USER/_PASS) to actually exercise it.
use DBI;

my $dsn  = $ENV{PERLA_TEST_PG_DSN}  || "dbi:Pg:dbname=perlatest;host=/tmp/pgsock;port=15432";
my $user = $ENV{PERLA_TEST_PG_USER} || "mflickin";
my $pass = $ENV{PERLA_TEST_PG_PASS} || "";

# RaiseError=>0 so a missing server returns undef instead of dying (no eval,
# which would take DBI.pm's $^S-sensitive path needing DBI/common.pm).
my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 0, PrintError => 0 });
unless (defined $dbh) {
    plan skip_all => "no PostgreSQL server reachable ($dsn)";
}

plan tests => 8;

ok($dbh->do("DROP TABLE IF EXISTS perla_t128"), "do DROP (0E0 true)");
ok($dbh->do("CREATE TABLE perla_t128 (id SERIAL PRIMARY KEY, name TEXT, age INT)"),
   "do CREATE TABLE");

my $ins = $dbh->prepare("INSERT INTO perla_t128 (name, age) VALUES (?, ?)");
ok($ins->execute("alice", 30), "execute insert with placeholders");
$ins->execute("bob",   25);
$ins->execute("carol", 41);

my $sth = $dbh->prepare("SELECT name, age FROM perla_t128 WHERE age > ? ORDER BY age");
$sth->execute(26);
my @got;
while (my @r = $sth->fetchrow_array) { push @got, "$r[0]:$r[1]"; }
is_deeply(\@got, ["alice:30", "carol:41"], "fetchrow_array + placeholder filter");

my $h = $dbh->prepare("SELECT id, name FROM perla_t128 WHERE name = ?");
$h->execute("bob");
my $row = $h->fetchrow_hashref;
is($row->{name}, "bob", "fetchrow_hashref name");

my $all = $dbh->selectall_arrayref("SELECT name FROM perla_t128 ORDER BY name");
is_deeply([ map { $_->[0] } @$all ], ["alice", "bob", "carol"], "selectall_arrayref");

my @cnt = $dbh->selectrow_array("SELECT COUNT(*) FROM perla_t128");
is($cnt[0], 3, "selectrow_array COUNT(*)");

my $aff = $dbh->do("UPDATE perla_t128 SET age = age + 1 WHERE age < ?", undef, 30);
is($aff, 1, "do UPDATE returns affected rows");

$dbh->do("DROP TABLE perla_t128");
$dbh->disconnect;
