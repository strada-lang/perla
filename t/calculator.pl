use strict;
use warnings;

# A complete expression calculator with tokenizer, parser, and evaluator
# Tests Perla's ability to handle real compiler-like code

package Calc::Token;
sub new { return bless({ type => $_[1], value => $_[2] }, "Calc::Token"); }
sub type { return $_[0]->{type}; }
sub value { return $_[0]->{value}; }

package Calc::Lexer;

sub tokenize {
    my ($class, $input) = @_;
    my @tokens = ();
    my $pos = 0;
    my $len = length($input);

    while ($pos < $len) {
        my $ch = substr($input, $pos, 1);

        # Skip whitespace
        if ($ch eq " " || $ch eq "\t") { $pos++; next; }

        # Numbers (including floats)
        if (($ch ge "0" && $ch le "9") || $ch eq ".") {
            my $num = "";
            while ($pos < $len) {
                my $c = substr($input, $pos, 1);
                if (($c ge "0" && $c le "9") || $c eq ".") {
                    $num = $num . $c;
                    $pos++;
                } else { last; }
            }
            push(@tokens, Calc::Token::new("Calc::Token", "NUM", $num));
            next;
        }

        # Operators
        if ($ch eq "+" || $ch eq "-" || $ch eq "*" || $ch eq "/" || $ch eq "%" || $ch eq "^") {
            push(@tokens, Calc::Token::new("Calc::Token", "OP", $ch));
            $pos++;
            next;
        }

        # Parentheses
        if ($ch eq "(") { push(@tokens, Calc::Token::new("Calc::Token", "LPAREN", "(")); $pos++; next; }
        if ($ch eq ")") { push(@tokens, Calc::Token::new("Calc::Token", "RPAREN", ")")); $pos++; next; }

        # Functions (sin, cos, sqrt, abs)
        if (($ch ge "a" && $ch le "z") || ($ch ge "A" && $ch le "Z")) {
            my $word = "";
            while ($pos < $len) {
                my $c = substr($input, $pos, 1);
                if (($c ge "a" && $c le "z") || ($c ge "A" && $c le "Z")) {
                    $word = $word . $c;
                    $pos++;
                } else { last; }
            }
            push(@tokens, Calc::Token::new("Calc::Token", "FUNC", $word));
            next;
        }

        $pos++;  # skip unknown
    }

    push(@tokens, Calc::Token::new("Calc::Token", "EOF", ""));
    return @tokens;
}

package Calc::Parser;

sub new {
    my ($class, @tokens) = @_;
    return bless({ tokens => \@tokens, pos => 0 }, $class);
}

sub current { return $_[0]->{tokens}->[$_[0]->{pos}]; }
sub advance { my $t = $_[0]->current(); $_[0]->{pos}++; return $t; }
sub expect {
    my ($self, $type) = @_;
    my $t = $self->current();
    if ($t->type() ne $type) {
        die "Expected " . $type . ", got " . $t->type();
    }
    return $self->advance();
}

# expr = term (('+' | '-') term)*
sub parse_expr {
    my ($self) = @_;
    my $left = $self->parse_term();
    while ($self->current()->type() eq "OP" &&
           ($self->current()->value() eq "+" || $self->current()->value() eq "-")) {
        my $op = $self->advance()->value();
        my $right = $self->parse_term();
        $left = { type => "binop", op => $op, left => $left, right => $right };
    }
    return $left;
}

# term = power (('*' | '/' | '%') power)*
sub parse_term {
    my ($self) = @_;
    my $left = $self->parse_power();
    while ($self->current()->type() eq "OP" &&
           ($self->current()->value() eq "*" || $self->current()->value() eq "/" || $self->current()->value() eq "%")) {
        my $op = $self->advance()->value();
        my $right = $self->parse_power();
        $left = { type => "binop", op => $op, left => $left, right => $right };
    }
    return $left;
}

# power = unary ('^' power)?
sub parse_power {
    my ($self) = @_;
    my $base = $self->parse_unary();
    if ($self->current()->type() eq "OP" && $self->current()->value() eq "^") {
        $self->advance();
        my $exp = $self->parse_power();  # right-associative
        return { type => "binop", op => "^", left => $base, right => $exp };
    }
    return $base;
}

# unary = '-' unary | primary
sub parse_unary {
    my ($self) = @_;
    if ($self->current()->type() eq "OP" && $self->current()->value() eq "-") {
        $self->advance();
        my $operand = $self->parse_unary();
        return { type => "unary", op => "-", operand => $operand };
    }
    return $self->parse_primary();
}

# primary = NUM | FUNC '(' expr ')' | '(' expr ')'
sub parse_primary {
    my ($self) = @_;
    my $tok = $self->current();

    if ($tok->type() eq "NUM") {
        $self->advance();
        return { type => "num", value => $tok->value() };
    }

    if ($tok->type() eq "FUNC") {
        my $name = $self->advance()->value();
        $self->expect("LPAREN");
        my $arg = $self->parse_expr();
        $self->expect("RPAREN");
        return { type => "func", name => $name, arg => $arg };
    }

    if ($tok->type() eq "LPAREN") {
        $self->advance();
        my $expr = $self->parse_expr();
        $self->expect("RPAREN");
        return $expr;
    }

    die "Unexpected token: " . $tok->type() . " '" . $tok->value() . "'";
}

package Calc::Eval;

sub evaluate {
    my ($class, $node) = @_;

    if ($node->{type} eq "num") {
        return $node->{value} + 0;  # convert to number
    }

    if ($node->{type} eq "binop") {
        my $l = Calc::Eval::evaluate("Calc::Eval", $node->{left});
        my $r = Calc::Eval::evaluate("Calc::Eval", $node->{right});
        if ($node->{op} eq "+") { return $l + $r; }
        if ($node->{op} eq "-") { return $l - $r; }
        if ($node->{op} eq "*") { return $l * $r; }
        if ($node->{op} eq "/") { return $l / $r; }
        if ($node->{op} eq "%") { return $l % $r; }
        if ($node->{op} eq "^") {
            my $result = 1;
            my $i = 0;
            while ($i < $r) { $result = $result * $l; $i++; }
            return $result;
        }
    }

    if ($node->{type} eq "unary") {
        my $val = Calc::Eval::evaluate("Calc::Eval", $node->{operand});
        if ($node->{op} eq "-") { return -$val; }
    }

    if ($node->{type} eq "func") {
        my $arg = Calc::Eval::evaluate("Calc::Eval", $node->{arg});
        if ($node->{name} eq "abs") { return abs($arg); }
        if ($node->{name} eq "sqrt") { return $arg; }  # simplified
        if ($node->{name} eq "double") { return $arg * 2; }
    }

    return 0;
}

package Calc;

sub calc {
    my ($class, $input) = @_;
    my @tokens = Calc::Lexer::tokenize("Calc::Lexer", $input);
    my $parser = Calc::Parser::new("Calc::Parser", @tokens);
    my $ast = $parser->parse_expr();
    return Calc::Eval::evaluate("Calc::Eval", $ast);
}

package main;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# Basic arithmetic
ok(Calc::calc("Calc", "2 + 3") == 5, "2+3=5");
ok(Calc::calc("Calc", "10 - 3") == 7, "10-3=7");
ok(Calc::calc("Calc", "4 * 5") == 20, "4*5=20");
ok(Calc::calc("Calc", "15 / 3") == 5, "15/3=5");
ok(Calc::calc("Calc", "17 % 5") == 2, "17%5=2");

# Precedence
ok(Calc::calc("Calc", "2 + 3 * 4") == 14, "2+3*4=14");
ok(Calc::calc("Calc", "(2 + 3) * 4") == 20, "(2+3)*4=20");
ok(Calc::calc("Calc", "10 - 2 * 3") == 4, "10-2*3=4");

# Unary minus
ok(Calc::calc("Calc", "-5") == -5, "unary -5");
ok(Calc::calc("Calc", "-5 + 10") == 5, "-5+10=5");

# Power
ok(Calc::calc("Calc", "2 ^ 10") == 1024, "2^10=1024");

# Functions
ok(Calc::calc("Calc", "abs(-42)") == 42, "abs(-42)");
ok(Calc::calc("Calc", "double(21)") == 42, "double(21)");

# Complex expressions
ok(Calc::calc("Calc", "(2 + 3) * (4 - 1)") == 15, "(2+3)*(4-1)=15");
ok(Calc::calc("Calc", "100 / (2 + 3) * 2") == 40, "100/(2+3)*2=40");

# Floats
ok(Calc::calc("Calc", "3.14 * 2") > 6.2, "3.14*2>6.2");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All calculator tests passed!\n"; }
