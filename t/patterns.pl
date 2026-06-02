use strict;
use warnings;

# --- $@ after eval ---
eval {
    die "test error\n";
};
my $err = $@;
if ($err) {
    print "Caught: " . $err;
}

# --- ||= default assignment ---
my %opts = ();
$opts{verbose} ||= 0;
$opts{output}  ||= "stdout";
print "verbose=" . $opts{verbose} . ", output=" . $opts{output} . "\n";

# --- Negative array index ---
my @arr = (10, 20, 30, 40, 50);
print "Last: " . $arr[-1] . "\n";
print "Second to last: " . $arr[-2] . "\n";
print "First: " . $arr[0] . "\n";

# --- do-while ---
my $counter = 0;
do {
    $counter++;
} while ($counter < 5);
print "Counter: " . $counter . "\n";

# --- Chained hash access with variable keys ---
my %data = (
    users => {
        alice => { age => 30, role => "admin" },
        bob   => { age => 25, role => "user" },
    },
);
my @usernames = ("alice", "bob");
foreach my $u (@usernames) {
    my $info = $data{users}->{$u};
    print $u . ": age=" . $info->{age} . ", role=" . $info->{role} . "\n";
}

# --- Array of hashes with computed keys ---
my @records = ();
my @names = ("one", "two", "three");
my $i = 0;
foreach my $n (@names) {
    push(@records, { name => $n, idx => $i });
    $i++;
}
foreach my $r (@records) {
    print $r->{name} . "=" . $r->{idx} . " ";
}
print "\n";

# --- String with special chars ---
my $path = "/usr/local/bin";
my @parts = split("/", $path);
# First element is empty string (before leading /)
print "Parts: " . join(" > ", @parts) . "\n";

# --- Numeric string conversion ---
my $num_str = "42";
my $result = $num_str + 8;
print "42 + 8 = " . $result . "\n";

# --- Boolean context ---
my $empty = "";
my $zero = 0;
my $filled = "hello";
print "empty is " . ($empty ? "true" : "false") . "\n";
print "zero is " . ($zero ? "true" : "false") . "\n";
print "filled is " . ($filled ? "true" : "false") . "\n";

# --- Multiline anon hash in function call ---
sub process_config {
    my ($config) = @_;
    return $config->{name} . " on port " . $config->{port};
}
my $desc = process_config({
    name => "MyServer",
    port => 8080,
});
print "Config: " . $desc . "\n";

print "All pattern tests passed!\n";
