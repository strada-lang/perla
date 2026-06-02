my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# 1. Nested closure capturing outer my vars (the big one)
sub make_counter {
    my $count = 0;
    my $inc = sub { $count++; return $count; };
    my $get = sub { return $count; };
    return ($inc, $get);
}
my ($inc, $get) = make_counter();
$inc->();
$inc->();
$inc->();
ok($get->() == 3, "closure capture: " . $get->());

# 2. Closure over loop variable
my @closures;
for my $i (1..3) {
    push(@closures, sub { return $i * 10; });
}
ok($closures[0]->() == 10, "loop closure 0: " . $closures[0]->());
ok($closures[1]->() == 20, "loop closure 1: " . $closures[1]->());
ok($closures[2]->() == 30, "loop closure 2: " . $closures[2]->());

# 3. Hash of closures (dispatch table)
my %ops = (
    add => sub { return $_[0] + $_[1]; },
    sub => sub { return $_[0] - $_[1]; },
    mul => sub { return $_[0] * $_[1]; },
);
ok($ops{add}->(3, 4) == 7, "dispatch add");
ok($ops{mul}->(5, 6) == 30, "dispatch mul");

# 4. Regex with captures in loop
my $log = "ERROR: disk full\nWARN: low mem\nINFO: started\nERROR: timeout";
my @errors;
for my $line (split(/\n/, $log)) {
    if ($line =~ /^(ERROR|WARN):\s+(.+)/) {
        push(@errors, {level => $1, msg => $2});
    }
}
ok(scalar(@errors) == 3, "log errors: " . scalar(@errors));
ok($errors[0]->{level} eq "ERROR", "first error level");
ok($errors[0]->{msg} eq "disk full", "first error msg");

# 5. Complex string processing
sub slug {
    my ($str) = @_;
    $str = lc($str);
    $str =~ s/[^a-z0-9\s]//g;
    $str =~ s/\s+/-/g;
    return $str;
}
ok(slug("Hello World!") eq "hello-world", "slug: " . slug("Hello World!"));
ok(slug("This is a TEST 123") eq "this-is-a-test-123", "slug 2");

# 6. Mini Markdown parser
sub md_to_html {
    my ($md) = @_;
    my @lines = split(/\n/, $md);
    my $html = "";
    for my $line (@lines) {
        if ($line =~ /^### (.+)/) { $html .= "<h3>$1</h3>\n"; }
        elsif ($line =~ /^## (.+)/) { $html .= "<h2>$1</h2>\n"; }
        elsif ($line =~ /^# (.+)/) { $html .= "<h1>$1</h1>\n"; }
        elsif ($line =~ /^\* (.+)/) { $html .= "<li>$1</li>\n"; }
        elsif ($line =~ /^---$/) { $html .= "<hr>\n"; }
        elsif ($line eq "") { $html .= "<br>\n"; }
        else { $html .= "<p>$line</p>\n"; }
    }
    return $html;
}
my $md = "# Title\n\nSome text\n\n## Section\n\n* Item 1\n* Item 2\n\n---";
my $html = md_to_html($md);
ok($html =~ /<h1>Title<\/h1>/, "md h1");
ok($html =~ /<h2>Section<\/h2>/, "md h2");
ok($html =~ /<li>Item 1<\/li>/, "md list");
ok($html =~ /<hr>/, "md hr");

# 7. Binary search
sub binary_search {
    my ($arr, $target) = @_;
    my $lo = 0;
    my $hi = scalar(@$arr) - 1;
    while ($lo <= $hi) {
        my $mid = int(($lo + $hi) / 2);
        if ($arr->[$mid] == $target) { return $mid; }
        elsif ($arr->[$mid] < $target) { $lo = $mid + 1; }
        else { $hi = $mid - 1; }
    }
    return -1;
}
my @sorted = (2, 5, 8, 12, 16, 23, 38, 56, 72, 91);
ok(binary_search(\@sorted, 23) == 5, "binary search found");
ok(binary_search(\@sorted, 99) == -1, "binary search not found");

# 8. Simple tokenizer
sub tokenize {
    my ($input) = @_;
    my @tokens;
    my $pos = 0;
    while ($pos < length($input)) {
        my $ch = substr($input, $pos, 1);
        # Skip whitespace
        if ($ch =~ /\s/) { $pos++; next; }
        # Number
        if ($ch =~ /\d/) {
            my $start = $pos;
            while ($pos < length($input) && substr($input, $pos, 1) =~ /\d/) { $pos++; }
            push(@tokens, {type => "NUM", val => substr($input, $start, $pos - $start)});
            next;
        }
        # Identifier
        if ($ch =~ /[a-zA-Z_]/) {
            my $start = $pos;
            while ($pos < length($input) && substr($input, $pos, 1) =~ /[a-zA-Z0-9_]/) { $pos++; }
            push(@tokens, {type => "ID", val => substr($input, $start, $pos - $start)});
            next;
        }
        # Operator
        push(@tokens, {type => "OP", val => $ch});
        $pos++;
    }
    return @tokens;
}
my @toks = tokenize("x = 42 + y");
ok(scalar(@toks) == 5, "tokenizer: " . scalar(@toks) . " tokens");
ok($toks[0]->{type} eq "ID", "token 0 type");
ok($toks[0]->{val} eq "x", "token 0 val");
ok($toks[2]->{type} eq "NUM", "token 2 type");
ok($toks[2]->{val} eq "42", "token 2 val");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All hard tests passed!\n"; }
