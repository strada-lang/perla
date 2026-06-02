#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native DBD::SQLite (libsqlite3): connect, do, prepare/execute with
# placeholders, fetchrow_array / fetchrow_hashref, selectall_arrayref,
# selectrow_array. No server needed; the DB is a temp file.
use DBI;

my $file = "/tmp/perla_t127_$$.sqlite";
unlink $file;
my $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "");
ok(defined($dbh), "connect to SQLite");

ok($dbh->do("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INT)"),
   "do CREATE TABLE");

my $ins = $dbh->prepare("INSERT INTO users (name, age) VALUES (?, ?)");
ok($ins->execute("alice", 30), "execute insert with placeholders (1)");
$ins->execute("bob",   25);
$ins->execute("carol", 41);

# fetchrow_array with a placeholder filter
my $sth = $dbh->prepare("SELECT name, age FROM users WHERE age > ? ORDER BY age");
$sth->execute(26);
my @got;
while (my @r = $sth->fetchrow_array) { push @got, "$r[0]:$r[1]"; }
is_deeply(\@got, ["alice:30", "carol:41"], "fetchrow_array + placeholder filter");

# fetchrow_hashref
my $h = $dbh->prepare("SELECT id, name FROM users WHERE name = ?");
$h->execute("bob");
my $row = $h->fetchrow_hashref;
is($row->{name}, "bob", "fetchrow_hashref: name");
is($row->{id},   2,     "fetchrow_hashref: id (autoincrement)");

# selectall_arrayref
my $all = $dbh->selectall_arrayref("SELECT name FROM users ORDER BY name");
is_deeply([ map { $_->[0] } @$all ], ["alice", "bob", "carol"], "selectall_arrayref");

# selectrow_array (aggregate)
my @cnt = $dbh->selectrow_array("SELECT COUNT(*) FROM users");
is($cnt[0], 3, "selectrow_array COUNT(*)");

# do with a bound value + affected-row count
my $aff = $dbh->do("UPDATE users SET age = age + 1 WHERE age < ?", undef, 30);
is($aff, 1, "do UPDATE returns affected rows");

$dbh->disconnect;
unlink $file;
done_testing;
