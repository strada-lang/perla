use strict;
use warnings;

# Text processing — classic Perl strength

# --- CSV-like data processing ---
my @csv_lines = (
    "name,age,city",
    "Alice,30,New York",
    "Bob,25,San Francisco",
    "Charlie,35,Chicago",
    "Diana,28,Boston",
);

# Parse header
my $header = $csv_lines[0];
my @fields = split(",", $header);
print "Fields: " . join(" | ", @fields) . "\n";

# Parse data rows
my @people = ();
my $i = 1;
while ($i < scalar(@csv_lines)) {
    my @vals = split(",", $csv_lines[$i]);
    my %person = ();
    my $j = 0;
    while ($j < scalar(@fields)) {
        $person{$fields[$j]} = $vals[$j];
        $j++;
    }
    push(@people, \%person);
    $i++;
}

# Print parsed data
foreach my $p (@people) {
    print $p->{name} . " is " . $p->{age} . " from " . $p->{city} . "\n";
}

# --- Word frequency counter ---
my $text = "the quick brown fox jumps over the lazy dog the fox the dog";
my @words = split(" ", $text);
my %freq = ();
foreach my $w (@words) {
    if (exists($freq{$w})) {
        $freq{$w} += 1;
    } else {
        $freq{$w} = 1;
    }
}

print "\nWord frequencies:\n";
foreach my $w (sort(keys(%freq))) {
    print "  " . $w . ": " . $freq{$w} . "\n";
}

# --- Simple template expansion ---
sub expand_template {
    my ($template, %vars) = @_;
    foreach my $key (keys(%vars)) {
        my $placeholder = "{" . $key . "}";
        my $value = $vars{$key};
        # Use index/substr loop since regex with vars isn't supported yet
        my $pos = index($template, $placeholder);
        while ($pos >= 0) {
            my $before = substr($template, 0, $pos);
            my $after = substr($template, $pos + length($placeholder));
            $template = $before . $value . $after;
            $pos = index($template, $placeholder);
        }
    }
    return $template;
}

my $tmpl = "Hello {name}, welcome to {city}!";
my $expanded = expand_template($tmpl, name => "Eve", city => "Portland");
print "\nTemplate: " . $expanded . "\n";

# --- Build a report ---
sub build_report {
    my @records = @_;
    my @lines = ();
    push(@lines, "=== Report ===");
    my $total_age = 0;
    foreach my $r (@records) {
        push(@lines, $r->{name} . " (age " . $r->{age} . ", " . $r->{city} . ")");
        $total_age += $r->{age};
    }
    my $avg = $total_age / scalar(@records);
    push(@lines, "Average age: " . $avg);
    push(@lines, "=============");
    return join("\n", @lines);
}

my $report = build_report(@people);
print "\n" . $report . "\n";

print "\nText processing tests passed!\n";
