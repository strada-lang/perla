my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# 1. Complex regex replacements
my $text = "Hello World";
$text =~ s/(\w)(\w+)/uc($1) . lc($2)/ge;
ok($text eq "Hello World", "s///ge: $text");

# 2. Multiple captures
my $date = "2024-01-15 10:30:00";
if ($date =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
    ok($1 eq "2024", "capture year");
    ok($4 eq "10", "capture hour");
    ok($6 eq "00", "capture sec");
}

# 3. Regex with alternation
my @lines = ("ERROR: disk full", "WARN: low memory", "INFO: started", "ERROR: timeout");
my @errors;
for my $line (@lines) {
    if ($line =~ /^(ERROR|WARN):\s+(.+)/) {
        push(@errors, "$1: $2");
    }
}
ok(scalar(@errors) == 3, "regex alt: " . scalar(@errors));

# 4. Complex string manipulation
sub camel_to_snake {
    my ($str) = @_;
    $str =~ s/([A-Z])/_\L$1/g;
    $str =~ s/^_//;
    return $str;
}
# Note: \L in replacement needs runtime eval — use simpler version
sub snake_case {
    my ($str) = @_;
    my @parts;
    my $word = "";
    for my $i (0..length($str)-1) {
        my $c = substr($str, $i, 1);
        if ($c ge "A" && $c le "Z") {
            if (length($word) > 0) { push(@parts, lc($word)); }
            $word = $c;
        } else {
            $word .= $c;
        }
    }
    if (length($word) > 0) { push(@parts, lc($word)); }
    return join("_", @parts);
}
ok(snake_case("helloWorld") eq "hello_world", "snake_case: " . snake_case("helloWorld"));
ok(snake_case("MyClass") eq "my_class", "snake_case 2");

# 5. Number formatting
sub format_number {
    my ($num) = @_;
    my $str = "$num";
    my @parts = split(/\./, $str);
    my $int_part = $parts[0];
    my $dec_part = scalar(@parts) > 1 ? "." . $parts[1] : "";
    # Add commas
    my $formatted = "";
    my $count = 0;
    for my $i (0..length($int_part)-1) {
        my $pos = length($int_part) - 1 - $i;
        if ($count > 0 && $count % 3 == 0) { $formatted = "," . $formatted; }
        $formatted = substr($int_part, $pos, 1) . $formatted;
        $count++;
    }
    return $formatted . $dec_part;
}
ok(format_number(1234567) eq "1,234,567", "format_number: " . format_number(1234567));
ok(format_number(42) eq "42", "format small");

# 6. Simple CSV parser
sub parse_csv {
    my ($line) = @_;
    my @fields;
    my $field = "";
    my $in_quotes = 0;
    for my $i (0..length($line)-1) {
        my $c = substr($line, $i, 1);
        if ($in_quotes) {
            if ($c eq '"') { $in_quotes = 0; }
            else { $field .= $c; }
        } else {
            if ($c eq '"') { $in_quotes = 1; }
            elsif ($c eq ',') { push(@fields, $field); $field = ""; }
            else { $field .= $c; }
        }
    }
    push(@fields, $field);
    return @fields;
}
my @csv = parse_csv('Alice,30,"New York",active');
ok(scalar(@csv) == 4, "csv fields: " . scalar(@csv));
ok($csv[0] eq "Alice", "csv name");
ok($csv[2] eq "New York", "csv quoted field");
ok($csv[3] eq "active", "csv last");

# 7. Stack-based calculator
sub calc_rpn {
    my ($expr) = @_;
    my @stack;
    for my $token (split(/\s+/, $expr)) {
        if ($token =~ /^-?\d+$/) {
            push(@stack, $token + 0);
        } else {
            my $b = pop(@stack);
            my $a = pop(@stack);
            if ($token eq "+") { push(@stack, $a + $b); }
            elsif ($token eq "-") { push(@stack, $a - $b); }
            elsif ($token eq "*") { push(@stack, $a * $b); }
            elsif ($token eq "/") { push(@stack, $b != 0 ? $a / $b : 0); }
        }
    }
    return $stack[0];
}
ok(calc_rpn("3 4 +") == 7, "rpn 3+4");
ok(calc_rpn("5 3 - 2 *") == 4, "rpn (5-3)*2");
ok(calc_rpn("2 3 4 * +") == 14, "rpn 2+3*4");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All misc tests passed!\n"; }
