use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Simple expression evaluator: tokenize, parse, evaluate
# Supports: +, -, *, /, (), integers, floats, variables

our %vars = ();

sub tokenize {
    my ($input) = @_;
    my @tokens = ();
    my $i = 0;
    my $len = length($input);
    while ($i < $len) {
        my $ch = substr($input, $i, 1);
        if ($ch eq " " || $ch eq "\t") { $i++; next; }
        if ($ch =~ /[0-9]/ || ($ch eq "." && $i + 1 < $len && substr($input, $i+1, 1) =~ /[0-9]/)) {
            my $num = "";
            while ($i < $len && (substr($input, $i, 1) =~ /[0-9]/ || substr($input, $i, 1) eq ".")) {
                $num .= substr($input, $i, 1);
                $i++;
            }
            push(@tokens, { type => "NUM", value => $num });
            next;
        }
        if ($ch =~ /[a-zA-Z_]/) {
            my $name = "";
            while ($i < $len && substr($input, $i, 1) =~ /[a-zA-Z_0-9]/) {
                $name .= substr($input, $i, 1);
                $i++;
            }
            push(@tokens, { type => "VAR", value => $name });
            next;
        }
        if ($ch eq "+" || $ch eq "-" || $ch eq "*" || $ch eq "/") {
            push(@tokens, { type => "OP", value => $ch });
            $i++;
            next;
        }
        if ($ch eq "(") { push(@tokens, { type => "LPAREN", value => "(" }); $i++; next; }
        if ($ch eq ")") { push(@tokens, { type => "RPAREN", value => ")" }); $i++; next; }
        if ($ch eq "=") { push(@tokens, { type => "ASSIGN", value => "=" }); $i++; next; }
        $i++;
    }
    return @tokens;
}

# Recursive descent parser + evaluator
our $tok_pos = 0;
our @tok_list = ();

sub eval_expr {
    my ($input) = @_;
    @tok_list = tokenize($input);
    $tok_pos = 0;
    return parse_assign();
}

sub peek_tok {
    if ($tok_pos >= scalar(@tok_list)) { return undef; }
    return $tok_list[$tok_pos];
}

sub next_tok {
    my $t = $tok_list[$tok_pos];
    $tok_pos++;
    return $t;
}

sub parse_assign {
    my $left = parse_add();
    my $tok = peek_tok();
    if (defined($tok) && $tok->{type} eq "ASSIGN") {
        next_tok();
        my $val = parse_add();
        $vars{$left} = $val;
        return $val;
    }
    return $left;
}

sub parse_add {
    my $left = parse_mul();
    while (1) {
        my $tok = peek_tok();
        if (!defined($tok)) { last; }
        if ($tok->{type} ne "OP") { last; }
        if ($tok->{value} ne "+" && $tok->{value} ne "-") { last; }
        next_tok();
        my $right = parse_mul();
        if ($tok->{value} eq "+") { $left = $left + $right; }
        else { $left = $left - $right; }
    }
    return $left;
}

sub parse_mul {
    my $left = parse_primary();
    while (1) {
        my $tok = peek_tok();
        if (!defined($tok)) { last; }
        if ($tok->{type} ne "OP") { last; }
        if ($tok->{value} ne "*" && $tok->{value} ne "/") { last; }
        next_tok();
        my $right = parse_primary();
        if ($tok->{value} eq "*") { $left = $left * $right; }
        else { $left = $left / $right; }
    }
    return $left;
}

sub parse_primary {
    my $tok = next_tok();
    if ($tok->{type} eq "NUM") { return $tok->{value} + 0; }
    if ($tok->{type} eq "VAR") {
        if (exists($vars{$tok->{value}})) { return $vars{$tok->{value}}; }
        return $tok->{value};  # Return name for assignment
    }
    if ($tok->{type} eq "LPAREN") {
        my $val = parse_add();
        next_tok();  # consume RPAREN
        return $val;
    }
    if ($tok->{type} eq "OP" && $tok->{value} eq "-") {
        return -parse_primary();
    }
    return 0;
}

# Test evaluation
ok(eval_expr("2 + 3") == 5, "add");
ok(eval_expr("10 - 3") == 7, "sub");
ok(eval_expr("4 * 5") == 20, "mul");
ok(eval_expr("15 / 3") == 5, "div");
ok(eval_expr("2 + 3 * 4") == 14, "precedence");
ok(eval_expr("(2 + 3) * 4") == 20, "parens");
ok(eval_expr("-5 + 3") == -2, "unary minus");
ok(eval_expr("1.5 * 2") == 3, "float");

# Variable assignment
eval_expr("x = 10");
ok(eval_expr("x + 5") == 15, "var use");
eval_expr("y = x * 2");
ok(eval_expr("y") == 20, "var chain");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All eval tests passed!\n"; }
