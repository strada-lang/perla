use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

package DB;
our @_rows = ();
our %_index = ();
our $next_id = 1;

sub insert {
    my ($class, %row) = @_;
    my $id = $next_id;
    $next_id++;
    $row{id} = $id;
    push(@_rows, \%row);
    $_index{$id} = \%row;
    return $id;
}

sub find {
    my ($class, $id) = @_;
    if (exists($_index{$id})) {
        return $_index{$id};
    }
    return undef;
}

sub where {
    my ($class, $field, $value) = @_;
    my @results = ();
    foreach my $row (@_rows) {
        if ($row->{$field} eq $value) {
            push(@results, $row);
        }
    }
    return @results;
}

sub count { return scalar(@_rows); }

sub update {
    my ($class, $id, %updates) = @_;
    my $row = DB::find("DB", $id);
    if (!defined($row)) { return 0; }
    foreach my $k (keys(%updates)) {
        $row->{$k} = $updates{$k};
    }
    return 1;
}

package main;

my $id1 = DB::insert("DB", name => "Alice", role => "admin");
my $id2 = DB::insert("DB", name => "Bob", role => "user");
my $id3 = DB::insert("DB", name => "Charlie", role => "user");

ok($id1 == 1, "insert id 1");
ok(DB::count() == 3, "count 3");

my $user = DB::find("DB", 2);
ok(defined($user), "find defined");
ok($user->{name} eq "Bob", "find name");

my @admins = DB::where("DB", "role", "admin");
ok(scalar(@admins) == 1, "where count");
ok($admins[0]->{name} eq "Alice", "where name");

DB::update("DB", 2, name => "Bobby");
$user = DB::find("DB", 2);
ok($user->{name} eq "Bobby", "update name");

my @all_rows = DB::where("DB", "role", "admin");
ok(scalar(@all_rows) == 1, "where admin");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All ORM tests passed!\n"; }
