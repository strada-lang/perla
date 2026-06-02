use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Text processing utilities
sub trim { my ($s) = @_; $s =~ s/^\s+//; $s =~ s/\s+$//; return $s; }
sub ltrim { my ($s) = @_; $s =~ s/^\s+//; return $s; }
sub rtrim { my ($s) = @_; $s =~ s/\s+$//; return $s; }

sub pad_right { my ($s, $width) = @_; return sprintf("%-" . $width . "s", $s); }
sub pad_left { my ($s, $width) = @_; return sprintf("%" . $width . "s", $s); }

sub wrap_text {
    my ($text, $width) = @_;
    my @words = split(/\s+/, $text);
    my @lines = ();
    my $current = "";
    foreach my $word (@words) {
        if (length($current) == 0) {
            $current = $word;
        } elsif (length($current) + 1 + length($word) <= $width) {
            $current .= " " . $word;
        } else {
            push(@lines, $current);
            $current = $word;
        }
    }
    if (length($current) > 0) { push(@lines, $current); }
    return join("\n", @lines);
}

sub count_words { my ($text) = @_; my @w = split(/\s+/, trim($text)); return scalar(@w); }

sub extract_emails {
    my ($text) = @_;
    my @emails = ();
    my @words = split(/\s+/, $text);
    foreach my $w (@words) {
        if ($w =~ /\w+\@\w+\.\w+/) {
            push(@emails, $w);
        }
    }
    return @emails;
}

sub snake_case {
    my ($s) = @_;
    $s =~ s/([A-Z])/_$1/g;
    $s =~ s/^_//;
    return lc($s);
}

sub camel_case {
    my ($s) = @_;
    my @parts = split(/_/, $s);
    my @result = ();
    foreach my $p (@parts) {
        push(@result, ucfirst($p));
    }
    return join("", @result);
}

# Tests
ok(trim("  hello  ") eq "hello", "trim");
ok(ltrim("  hello  ") eq "hello  ", "ltrim");
ok(rtrim("  hello  ") eq "  hello", "rtrim");

ok(pad_right("hi", 10) eq "hi        ", "pad_right");
ok(pad_left("hi", 10) eq "        hi", "pad_left");

my $wrapped = wrap_text("the quick brown fox jumps over the lazy dog", 20);
my @wlines = split(/\n/, $wrapped);
ok(scalar(@wlines) >= 2, "wrap lines: " . scalar(@wlines));
ok(length($wlines[0]) <= 20, "wrap width");

ok(count_words("hello world foo bar") == 4, "count_words");
ok(count_words("  spaced   out  ") == 2, "count_words spaced");

my @emails = extract_emails("Contact alice\@example.com or bob\@test.org for info");
ok(scalar(@emails) == 2, "extract emails count");
ok($emails[0] eq "alice\@example.com", "email 1: " . $emails[0]);

ok(snake_case("HelloWorld") eq "hello_world", "snake_case: " . snake_case("HelloWorld"));
ok(camel_case("hello_world") eq "HelloWorld", "camel_case: " . camel_case("hello_world"));

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All text tool tests passed!\n"; }
