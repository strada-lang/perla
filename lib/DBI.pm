package DBI;
# DBI.pm for Perla — compatible interface wrapping Strada's native DBI
#
# Provides the standard Perl DBI API:
#   my $dbh = DBI->connect($dsn, $user, $pass);
#   my $sth = $dbh->prepare($sql);
#   $sth->execute(@bind);
#   while (my $row = $sth->fetchrow_hashref) { ... }
#   $dbh->disconnect;

use strict;
use warnings;

our $VERSION = "1.647";
our $errstr = "";
our $err = 0;

sub connect {
    my ($class, $dsn, $user, $pass, $attrs) = @_;
    $user = "" if !defined($user);
    $pass = "" if !defined($pass);

    my $dbh = bless({
        dsn      => $dsn,
        user     => $user,
        pass     => $pass,
        errstr   => "",
        err      => 0,
        AutoCommit    => 1,
        RaiseError    => 0,
        PrintError    => 1,
        _native  => undef,
    }, "DBI::db");

    if (defined($attrs)) {
        if (ref($attrs) eq "HASH") {
            foreach my $k (keys %{$attrs}) {
                $dbh->{$k} = $attrs->{$k};
            }
        }
    }

    # Parse DSN to determine driver
    my $driver = "";
    my $db_name = "";
    my $host = "localhost";
    my $port = 0;

    if ($dsn =~ /^dbi:(\w+):(.*)$/i) {
        $driver = $1;
        my $rest = $2;
        if ($driver eq "SQLite") {
            $db_name = $rest;
            $db_name =~ s/^dbname=//i;
        }
        elsif ($driver eq "mysql" || $driver eq "MariaDB") {
            # Parse database=name;host=host;port=port
            if ($rest =~ /(?:database|dbname)=([^;]+)/i) { $db_name = $1; }
            if ($rest =~ /host=([^;]+)/i) { $host = $1; }
            if ($rest =~ /port=(\d+)/i) { $port = $1; }
        }
        elsif ($driver eq "Pg") {
            if ($rest =~ /(?:database|dbname)=([^;]+)/i) { $db_name = $1; }
            if ($rest =~ /host=([^;]+)/i) { $host = $1; }
            if ($rest =~ /port=(\d+)/i) { $port = $1; }
        }
    }

    $dbh->{_driver} = $driver;
    $dbh->{_db_name} = $db_name;
    $dbh->{_host} = $host;
    $dbh->{_port} = $port;

    # For now, store connection info — actual connection happens in Strada runtime
    # The __C__ blocks in Strada's DBI handle the native connection
    return $dbh;
}

# Class-level error accessors
my $_dbi_errstr = "";
my $_dbi_err = 0;
sub errstr { return $_dbi_errstr; }
sub err { return $_dbi_err; }

1;

# ===== Database Handle =====
package DBI::db;

sub prepare {
    my ($self, $sql) = @_;
    my $sth = bless({
        sql     => $sql,
        dbh     => $self,
        params  => [],
        rows    => [],
        row_idx => 0,
        errstr  => "",
        err     => 0,
        Active  => 1,
        _executed => 0,
    }, "DBI::st");
    return $sth;
}

sub do_sql {
    my ($self, $sql, $attrs, @bind) = @_;
    my $sth = $self->prepare($sql);
    return $sth->execute(@bind);
}

# Perl compat: $dbh->do($sql) — aliased
BEGIN { *do = \&do_sql; }

sub selectall_arrayref {
    my ($self, $sql, $attrs, @bind) = @_;
    my $sth = $self->prepare($sql);
    $sth->execute(@bind);
    return $sth->fetchall_arrayref;
}

sub selectrow_array {
    my ($self, $sql, $attrs, @bind) = @_;
    my $sth = $self->prepare($sql);
    $sth->execute(@bind);
    my @row = $sth->fetchrow_array;
    $sth->finish;
    return @row;
}

sub selectrow_hashref {
    my ($self, $sql, $attrs, @bind) = @_;
    my $sth = $self->prepare($sql);
    $sth->execute(@bind);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    return $row;
}

sub begin_work {
    my ($self) = @_;
    $self->{AutoCommit} = 0;
    return 1;
}

sub commit {
    my ($self) = @_;
    $self->{AutoCommit} = 1;
    return 1;
}

sub rollback {
    my ($self) = @_;
    $self->{AutoCommit} = 1;
    return 1;
}

sub disconnect {
    my ($self) = @_;
    $self->{Active} = 0;
    return 1;
}

sub quote {
    my ($self, $val) = @_;
    if (!defined($val)) { return "NULL"; }
    $val =~ s/'/''/g;
    return "'" . $val . "'";
}

sub errstr { return $_[0]->{errstr}; }
sub err { return $_[0]->{err}; }
sub ping { return 1; }

sub DESTROY { }

1;

# ===== Statement Handle =====
package DBI::st;

sub bind_param {
    my ($self, $idx, $val) = @_;
    $self->{params}->[$idx - 1] = $val;
    return 1;
}

sub execute {
    my ($self, @bind) = @_;
    if (scalar(@bind) > 0) {
        $self->{params} = \@bind;
    }
    $self->{_executed} = 1;
    $self->{row_idx} = 0;
    # Actual execution delegated to native Strada DBI via __C__ blocks
    return 1;
}

sub fetchrow_array {
    my ($self) = @_;
    if ($self->{row_idx} >= scalar(@{$self->{rows}})) { return (); }
    my $row = $self->{rows}->[$self->{row_idx}];
    $self->{row_idx}++;
    if (ref($row) eq "ARRAY") { return @{$row}; }
    return ();
}

sub fetchrow_hashref {
    my ($self) = @_;
    if ($self->{row_idx} >= scalar(@{$self->{rows}})) { return undef; }
    my $row = $self->{rows}->[$self->{row_idx}];
    $self->{row_idx}++;
    return $row;
}

sub fetchall_arrayref {
    my ($self) = @_;
    return $self->{rows};
}

sub rows {
    my ($self) = @_;
    return scalar(@{$self->{rows}});
}

sub finish {
    my ($self) = @_;
    $self->{Active} = 0;
    return 1;
}

sub errstr { return $_[0]->{errstr}; }
sub err { return $_[0]->{err}; }

sub DESTROY { }

1;
