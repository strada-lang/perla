use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Log entry parser
sub parse_log_line {
    my ($line) = @_;
    # Format: YYYY-MM-DD HH:MM:SS [LEVEL] message
    if ($line =~ /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$/) {
        return { date => $1, time => $2, level => $3, message => $4 };
    }
    return undef;
}

# Log analyzer
package LogAnalyzer;

sub new {
    my ($class) = @_;
    return bless({
        entries    => [],
        by_level   => {},
        count      => 0,
    }, $class);
}

sub add_line {
    my ($self, $line) = @_;
    my $entry = main::parse_log_line($line);
    return unless defined($entry);
    push(@{$self->{entries}}, $entry);
    $self->{count}++;
    my $level = $entry->{level};
    if (!exists($self->{by_level}{$level})) {
        $self->{by_level}{$level} = 0;
    }
    $self->{by_level}{$level} += 1;
}

sub count { return $_[0]->{count}; }

sub level_count {
    my ($self, $level) = @_;
    if (exists($self->{by_level}{$level})) {
        return $self->{by_level}{$level};
    }
    return 0;
}

sub filter_level {
    my ($self, $level) = @_;
    my @filtered = ();
    foreach my $e (@{$self->{entries}}) {
        if ($e->{level} eq $level) {
            push(@filtered, $e);
        }
    }
    return @filtered;
}

sub search {
    my ($self, $pattern) = @_;
    my @results = ();
    foreach my $e (@{$self->{entries}}) {
        if (index($e->{message}, $pattern) >= 0) {
            push(@results, $e);
        }
    }
    return @results;
}

sub summary {
    my ($self) = @_;
    my @lines = ();
    push(@lines, "Total entries: " . $self->{count});
    foreach my $level (sort(keys(%{$self->{by_level}}))) {
        push(@lines, "  " . $level . ": " . $self->{by_level}{$level});
    }
    return join("\n", @lines);
}

package main;

# Sample log data
my @log_data = (
    "2024-01-15 08:00:01 [INFO] Application started",
    "2024-01-15 08:00:02 [INFO] Loading configuration",
    "2024-01-15 08:00:03 [DEBUG] Config file: /etc/app.conf",
    "2024-01-15 08:00:05 [INFO] Database connected",
    "2024-01-15 08:01:00 [WARN] Slow query detected: 2.5s",
    "2024-01-15 08:02:00 [ERROR] Connection refused: redis:6379",
    "2024-01-15 08:02:01 [ERROR] Cache unavailable, using fallback",
    "2024-01-15 08:03:00 [INFO] Request processed: GET /api/users",
    "2024-01-15 08:03:01 [DEBUG] Response time: 45ms",
    "2024-01-15 08:04:00 [WARN] Memory usage above 80%",
);

my $analyzer = LogAnalyzer::new("LogAnalyzer");
foreach my $line (@log_data) {
    $analyzer->add_line($line);
}

# Test basic parsing
ok($analyzer->count() == 10, "total count");
ok($analyzer->level_count("INFO") == 4, "INFO count");
ok($analyzer->level_count("ERROR") == 2, "ERROR count");
ok($analyzer->level_count("DEBUG") == 2, "DEBUG count");
ok($analyzer->level_count("WARN") == 2, "WARN count");

# Test filtering
my @errors = $analyzer->filter_level("ERROR");
ok(scalar(@errors) == 2, "filter ERROR count");
ok($errors[0]->{message} eq "Connection refused: redis:6379", "error msg 0");

# Test search
my @redis = $analyzer->search("redis");
ok(scalar(@redis) == 1, "search redis");
ok($redis[0]->{level} eq "ERROR", "search redis level");

my @query = $analyzer->search("query");
ok(scalar(@query) == 1, "search query");

# Test summary
my $summary = $analyzer->summary();
ok(index($summary, "Total entries: 10") >= 0, "summary total");
ok(index($summary, "ERROR: 2") >= 0, "summary errors");

# Test individual parse
my $entry = parse_log_line("2024-01-15 10:30:00 [CRITICAL] Disk full");
ok($entry->{level} eq "CRITICAL", "parse level");
ok($entry->{date} eq "2024-01-15", "parse date");
ok($entry->{message} eq "Disk full", "parse message");

# Test invalid line
my $bad = parse_log_line("not a log line");
ok(!defined($bad), "invalid line returns undef");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All log parser tests passed!\n"; }
