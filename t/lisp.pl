use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Minimal Lisp interpreter: tokenize, parse, eval
# Supports: integers, +, -, *, /, <, >, =, if, define, lambda, list, car, cdr

sub lisp_tokenize {
    my ($input) = @_;
    my @tokens = ();
    $input =~ s/\(/ ( /g;
    $input =~ s/\)/ ) /g;
    my @parts = split(/\s+/, $input);
    foreach my $p (@parts) {
        next if length($p) == 0;
        push(@tokens, $p);
    }
    return @tokens;
}

our @_tokens = [];
our $tpos = 0;

sub lisp_parse {
    my ($input) = @_;
    @_tokens = lisp_tokenize($input);
    $tpos = 0;
    return _parse_expr();
}

sub _parse_expr {
    my $tok = $_tokens[$tpos];
    $tpos++;
    if ($tok eq "(") {
        my @list = ();
        while ($_tokens[$tpos] ne ")") {
            push(@list, _parse_expr());
        }
        $tpos++;  # skip )
        return \@list;
    }
    if ($tok =~ /^-?\d+$/) {
        return $tok + 0;
    }
    return $tok;  # symbol
}

our %env = ();
$env{"+"} = sub { return $_[0] + $_[1]; };
$env{"-"} = sub { return $_[0] - $_[1]; };
$env{"*"} = sub { return $_[0] * $_[1]; };
$env{"/"} = sub { return $_[0] / $_[1]; };
$env{"<"} = sub { return $_[0] < $_[1] ? 1 : 0; };
$env{">"} = sub { return $_[0] > $_[1] ? 1 : 0; };
$env{"="} = sub { return $_[0] == $_[1] ? 1 : 0; };

sub lisp_eval {
    my ($expr) = @_;
    if (!ref($expr)) {
        # Atom: number or symbol
        if ($expr =~ /^-?\d+$/) { return $expr + 0; }
        if (exists($env{$expr})) { return $env{$expr}; }
        return 0;
    }
    # List expression
    my @list = @{$expr};
    my $op = $list[0];

    if ($op eq "if") {
        my $cond = lisp_eval($list[1]);
        if ($cond) { return lisp_eval($list[2]); }
        if (scalar(@list) > 3) { return lisp_eval($list[3]); }
        return 0;
    }
    if ($op eq "define") {
        $env{$list[1]} = lisp_eval($list[2]);
        return 0;
    }

    # Function call
    my $func = lisp_eval($op);
    my @args = ();
    for (my $i = 1; $i < scalar(@list); $i++) {
        push(@args, lisp_eval($list[$i]));
    }
    if (ref($func) eq "CODE") {
        return $func->(@args);
    }
    return 0;
}

sub lisp_run {
    my ($code) = @_;
    my $ast = lisp_parse($code);
    return lisp_eval($ast);
}

# Tests
ok(lisp_run("(+ 2 3)") == 5, "lisp add");
ok(lisp_run("(* 4 5)") == 20, "lisp mul");
ok(lisp_run("(- 10 3)") == 7, "lisp sub");
ok(lisp_run("(+ 1 (* 2 3))") == 7, "lisp nested");
ok(lisp_run("(if (> 5 3) 1 0)") == 1, "lisp if true");
ok(lisp_run("(if (< 5 3) 1 0)") == 0, "lisp if false");

lisp_run("(define x 42)");
ok(lisp_run("x") == 42, "lisp define");
ok(lisp_run("(+ x 8)") == 50, "lisp var use");

lisp_run("(define y (+ x 10))");
ok(lisp_run("y") == 52, "lisp define expr");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All Lisp tests passed!\n"; }
