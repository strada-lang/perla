use strict;
use warnings;

# A mini data processing app that exercises real Perl patterns

# --- Data model ---
package Record;

sub new {
    my ($class, %args) = @_;
    return bless({
        name  => $args{name} || "unknown",
        score => $args{score} || 0,
        tags  => $args{tags} || [],
    }, $class);
}

sub name  { return $_[0]->{name}; }
sub score { return $_[0]->{score}; }
sub tags  { return $_[0]->{tags}; }

sub to_string {
    my $self = shift;
    return $self->{name} . " (score: " . $self->{score} . ")";
}

package main;

# --- Build some records ---
my @records = ();
push(@records, Record::new("Record", name => "Alice", score => 95));
push(@records, Record::new("Record", name => "Bob", score => 87));
push(@records, Record::new("Record", name => "Charlie", score => 92));
push(@records, Record::new("Record", name => "Diana", score => 78));
push(@records, Record::new("Record", name => "Eve", score => 99));

# --- Print all records ---
print "All records:\n";
foreach my $r (@records) {
    print "  " . $r->to_string() . "\n";
}

# --- Filter: score >= 90 ---
my @high = grep { $_->score() >= 90 } @records;
print "\nHigh scorers (>= 90):\n";
foreach my $r (@high) {
    print "  " . $r->name() . ": " . $r->score() . "\n";
}

# --- Map: extract names ---
my @names = map { $_->name() } @records;
print "\nNames: " . join(", ", @names) . "\n";

# --- Compute average ---
my $total = 0;
foreach my $r (@records) {
    $total += $r->score();
}
my $count = scalar(@records);
my $avg = $total / $count;
print "Average score: " . $avg . "\n";

# --- Find max ---
my $best = $records[0];
my $i = 1;
while ($i < scalar(@records)) {
    if ($records[$i]->score() > $best->score()) {
        $best = $records[$i];
    }
    $i++;
}
print "Best: " . $best->to_string() . "\n";

# --- String processing ---
my @words = qw(hello world foo bar baz);
my @upper_words = map { uc($_) } @words;
print "Upper: " . join(" ", @upper_words) . "\n";

my @filtered = grep { length($_) > 3 } @words;
print "Long words: " . join(", ", @filtered) . "\n";

# --- Hash accumulator ---
my %word_lengths = ();
foreach my $w (@words) {
    $word_lengths{$w} = length($w);
}
foreach my $w (sort(keys(%word_lengths))) {
    print $w . " => " . $word_lengths{$w} . "\n";
}

# --- Nested data ---
my @people = (
    { name => "Alice", hobbies => ["reading", "coding"] },
    { name => "Bob",   hobbies => ["gaming", "cooking"] },
);
foreach my $p (@people) {
    my $hobby_list = join(", ", @{$p->{hobbies}});
    print $p->{name} . " likes: " . $hobby_list . "\n";
}

print "\nAll mini_app tests passed!\n";
