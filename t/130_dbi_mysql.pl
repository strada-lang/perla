#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native DBD::mysql (libmysqlclient). Needs a running MySQL/MariaDB server, so
# it SKIPS when none is reachable. Point it at a server with PERLA_TEST_MYSQL_DSN
# (+ _USER/_PASS) to exercise it.
use DBI;

my $dsn  = $ENV{PERLA_TEST_MYSQL_DSN}  || "dbi:mysql:database=perlatest;host=127.0.0.1;port=13306";
my $user = $ENV{PERLA_TEST_MYSQL_USER} || "perla";
my $pass = $ENV{PERLA_TEST_MYSQL_PASS} || "perlapw";

my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 0, PrintError => 0 });
unless (defined $dbh) {
    plan skip_all => "no MySQL server reachable ($dsn)";
}

plan tests => 7;

ok($dbh->do("DROP TABLE IF EXISTS perla_t130"), "do DROP");
ok($dbh->do("CREATE TABLE perla_t130 (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(64), age INT)"),
   "do CREATE TABLE");

my $ins = $dbh->prepare("INSERT INTO perla_t130 (name, age) VALUES (?, ?)");
ok($ins->execute("alice", 30), "execute insert with placeholders (str + int bind)");
$ins->execute("bob",   25);
$ins->execute("carol", 41);

my $sth = $dbh->prepare("SELECT name, age FROM perla_t130 WHERE age > ? ORDER BY age");
$sth->execute(26);
my @got;
while (my @r = $sth->fetchrow_array) { push @got, "$r[0]:$r[1]"; }
is_deeply(\@got, ["alice:30", "carol:41"], "fetchrow_array + placeholder filter");

my $all = $dbh->selectall_arrayref("SELECT name FROM perla_t130 ORDER BY name");
is_deeply([ map { $_->[0] } @$all ], ["alice", "bob", "carol"], "selectall_arrayref");

my @cnt = $dbh->selectrow_array("SELECT COUNT(*) FROM perla_t130");
is($cnt[0], 3, "selectrow_array COUNT(*)");

my $h = $dbh->prepare("SELECT age FROM perla_t130 WHERE name = ?");
$h->execute("carol");
my $row = $h->fetchrow_hashref;
is($row->{age}, 41, "fetchrow_hashref");

$dbh->do("DROP TABLE perla_t130");
$dbh->disconnect;
