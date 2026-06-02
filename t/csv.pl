use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# CSV Parser
sub parse_csv {
    my ($text) = @_;
    my @rows = ();
    my @lines = split(/\n/, $text);
    foreach my $line (@lines) {
        next if length($line) == 0;
        my @fields = split(/,/, $line);
        # Trim whitespace from each field
        my @trimmed = ();
        foreach my $f (@fields) {
            $f =~ s/^\s+//;
            $f =~ s/\s+$//;
            push(@trimmed, $f);
        }
        push(@rows, \@trimmed);
    }
    return @rows;
}

sub csv_to_hashes {
    my ($text) = @_;
    my @rows = parse_csv($text);
    if (scalar(@rows) < 2) { return (); }
    my @headers = @{$rows[0]};
    my @result = ();
    for (my $i = 1; $i < scalar(@rows); $i++) {
        my %row = ();
        for (my $j = 0; $j < scalar(@headers); $j++) {
            $row{$headers[$j]} = $rows[$i]->[$j];
        }
        push(@result, \%row);
    }
    return @result;
}

my $csv = "name, age, city
Alice, 30, NYC
Bob, 25, LA
Charlie, 35, Chicago";

my @data = csv_to_hashes($csv);
ok(scalar(@data) == 3, "csv row count");
ok($data[0]->{name} eq "Alice", "csv name 0");
ok($data[0]->{age} eq "30", "csv age 0");
ok($data[1]->{city} eq "LA", "csv city 1");
ok($data[2]->{name} eq "Charlie", "csv name 2");

# Generate CSV back
sub to_csv {
    my ($headers, @rows) = @_;
    my $out = join(",", @{$headers}) . "\n";
    foreach my $row (@rows) {
        my @vals = ();
        foreach my $h (@{$headers}) {
            push(@vals, $row->{$h});
        }
        $out .= join(",", @vals) . "\n";
    }
    return $out;
}

my @hdrs = ("name", "age", "city");
my $regenerated = to_csv(\@hdrs, @data);
ok(index($regenerated, "Alice,30,NYC") >= 0, "csv regenerate Alice");
ok(index($regenerated, "Bob,25,LA") >= 0, "csv regenerate Bob");

# Filter and transform
my @young = grep { $_->{age} < 30 } @data;
ok(scalar(@young) == 1, "csv filter young");
ok($young[0]->{name} eq "Bob", "csv filter name");

my @names = map { uc($_->{name}) } @data;
ok(join(",", @names) eq "ALICE,BOB,CHARLIE", "csv map uc: " . join(",", @names));

# Sort by age
my @by_age = sort { $a->{age} <=> $b->{age} } @data;
ok($by_age[0]->{name} eq "Bob", "csv sort youngest");
ok($by_age[2]->{name} eq "Charlie", "csv sort oldest");

# Simple aggregation
my $total_age = 0;
foreach my $d (@data) { $total_age += $d->{age}; }
my $avg_age = int($total_age / scalar(@data));
ok($avg_age == 30, "csv avg age: " . $avg_age);

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All CSV tests passed!\n"; }
