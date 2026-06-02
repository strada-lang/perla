use strict;
use warnings;

# Simple log analyzer — parses structured log lines and generates stats

package LogEntry;

sub new {
    my ($class, %args) = @_;
    return bless({
        timestamp => $args{timestamp} || "",
        level     => $args{level} || "INFO",
        message   => $args{message} || "",
        source    => $args{source} || "unknown",
    }, $class);
}

sub timestamp { return $_[0]->{timestamp}; }
sub level     { return $_[0]->{level}; }
sub message   { return $_[0]->{message}; }
sub source    { return $_[0]->{source}; }

sub to_string {
    my $self = shift;
    return "[" . $self->{timestamp} . "] " . $self->{level} . " " . $self->{source} . ": " . $self->{message};
}

package LogAnalyzer;

sub new {
    my ($class) = @_;
    return bless({
        entries => [],
        level_counts => {},
        source_counts => {},
    }, $class);
}

sub parse_line {
    my ($self, $line) = @_;
    # Format: TIMESTAMP LEVEL SOURCE: MESSAGE
    # Example: 2024-01-15T10:30:00 ERROR web: Connection timeout

    my $ts = "";
    my $level = "INFO";
    my $source = "unknown";
    my $msg = $line;

    # Extract timestamp (first space-delimited token)
    my $sp = index($line, " ");
    if ($sp > 0) {
        $ts = substr($line, 0, $sp);
        $line = substr($line, $sp + 1);
        $line =~ s/^\s+//;
    }

    # Extract level (second token)
    $sp = index($line, " ");
    if ($sp > 0) {
        my $tok = substr($line, 0, $sp);
        if ($tok eq "DEBUG" || $tok eq "INFO" || $tok eq "WARN" || $tok eq "ERROR" || $tok eq "FATAL") {
            $level = $tok;
            $line = substr($line, $sp + 1);
            $line =~ s/^\s+//;
        }
    }

    # Extract source (word before colon)
    my $colon = index($line, ":");
    if ($colon > 0) {
        $source = substr($line, 0, $colon);
        $source =~ s/^\s+//;
        $source =~ s/\s+$//;
        $msg = substr($line, $colon + 1);
        $msg =~ s/^\s+//;
    } else {
        $msg = $line;
    }

    my $entry = LogEntry::new("LogEntry",
        timestamp => $ts,
        level     => $level,
        message   => $msg,
        source    => $source,
    );

    push(@{$self->{entries}}, $entry);

    # Update counts
    if (!exists($self->{level_counts}{$level})) {
        $self->{level_counts}{$level} = 0;
    }
    $self->{level_counts}{$level} += 1;

    if (!exists($self->{source_counts}{$source})) {
        $self->{source_counts}{$source} = 0;
    }
    $self->{source_counts}{$source} += 1;

    return $entry;
}

sub total_entries {
    my ($self) = @_;
    return scalar(@{$self->{entries}});
}

sub entries_by_level {
    my ($self, $level) = @_;
    my @result = grep { $_->level() eq $level } @{$self->{entries}};
    return @result;
}

sub report {
    my ($self) = @_;
    my @lines = ();
    push(@lines, "=== Log Analysis Report ===");
    push(@lines, "Total entries: " . $self->total_entries());
    push(@lines, "");

    # Level breakdown
    push(@lines, "By Level:");
    foreach my $level (sort(keys(%{$self->{level_counts}}))) {
        push(@lines, "  " . $level . ": " . $self->{level_counts}{$level});
    }
    push(@lines, "");

    # Source breakdown
    push(@lines, "By Source:");
    foreach my $source (sort(keys(%{$self->{source_counts}}))) {
        push(@lines, "  " . $source . ": " . $self->{source_counts}{$source});
    }
    push(@lines, "");

    # Errors
    my @errors = $self->entries_by_level("ERROR");
    if (scalar(@errors) > 0) {
        push(@lines, "Errors (" . scalar(@errors) . "):");
        foreach my $e (@errors) {
            push(@lines, "  " . $e->to_string());
        }
    }

    push(@lines, "===========================");
    return join("\n", @lines);
}

package main;

my $analyzer = LogAnalyzer::new("LogAnalyzer");

# Parse log lines
my @log_lines = (
    "2024-01-15T10:30:00 INFO web: Server started on port 8080",
    "2024-01-15T10:30:01 DEBUG db: Connection pool initialized",
    "2024-01-15T10:30:05 INFO web: Request GET /api/users",
    "2024-01-15T10:30:06 WARN db: Slow query detected (2.5s)",
    "2024-01-15T10:30:10 ERROR web: Connection timeout to upstream",
    "2024-01-15T10:30:11 INFO auth: User login: alice@example.com",
    "2024-01-15T10:30:15 ERROR db: Deadlock detected on table users",
    "2024-01-15T10:30:20 INFO web: Request POST /api/data",
    "2024-01-15T10:30:25 WARN auth: Failed login attempt: bob@example.com",
    "2024-01-15T10:30:30 INFO web: Request GET /api/health",
);

foreach my $line (@log_lines) {
    $analyzer->parse_line($line);
}

# Print report
print $analyzer->report() . "\n";

# Verify counts
my $total = $analyzer->total_entries();
if ($total == 10) {
    print "Total count OK\n";
} else {
    print "FAIL: expected 10, got " . $total . "\n";
}

my @errors = $analyzer->entries_by_level("ERROR");
if (scalar(@errors) == 2) {
    print "Error count OK\n";
} else {
    print "FAIL: expected 2 errors, got " . scalar(@errors) . "\n";
}

print "Log analyzer test passed!\n";
