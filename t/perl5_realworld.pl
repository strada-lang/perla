use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# === URL Router Pattern ===
package Router;
sub new { return bless({routes => []}, $_[0]); }
sub get {
    my ($self, $path, $handler) = @_;
    push(@{$self->{routes}}, {method => "GET", path => $path, handler => $handler});
    return $self;
}
sub dispatch {
    my ($self, $method, $path) = @_;
    for my $route (@{$self->{routes}}) {
        if ($route->{method} eq $method && $route->{path} eq $path) {
            return $route->{handler}->();
        }
    }
    return {status => 404};
}

package main;
my $app = Router->new();
$app->get("/", sub { return {status => 200, body => "Home"}; });
$app->get("/about", sub { return {status => 200, body => "About"}; });
my $res = $app->dispatch("GET", "/");
ok($res->{status} == 200, "router dispatch");
ok($res->{body} eq "Home", "router body");
ok($app->dispatch("GET", "/missing")->{status} == 404, "router 404");

# === Template Engine ===
package Template;
sub new { return bless({}, $_[0]); }
sub render {
    my ($self, $tpl, $vars) = @_;
    my $out = $tpl;
    for my $key (keys %$vars) {
        my $ph = "{{" . $key . "}}";
        my $val = $vars->{$key};
        my $idx = index($out, $ph);
        while ($idx >= 0) {
            $out = substr($out, 0, $idx) . $val . substr($out, $idx + length($ph));
            $idx = index($out, $ph);
        }
    }
    return $out;
}

package main;
my $tpl = Template->new();
ok($tpl->render("Hello {{name}}", {name => "World"}) eq "Hello World", "template");

# === Data Processing ===
my @records = (
    {name => "Alice", dept => "eng", salary => 100},
    {name => "Bob", dept => "eng", salary => 120},
    {name => "Carol", dept => "sales", salary => 90},
    {name => "Dave", dept => "eng", salary => 110},
);

# Group by department
my %by_dept;
for my $rec (@records) {
    my $d = $rec->{dept};
    $by_dept{$d} = [] unless exists $by_dept{$d};
    push(@{$by_dept{$d}}, $rec);
}
ok(scalar(@{$by_dept{eng}}) == 3, "group by dept");

# Average salary per dept
my $eng_total = 0;
for my $r (@{$by_dept{eng}}) { $eng_total += $r->{salary}; }
ok($eng_total / scalar(@{$by_dept{eng}}) == 110, "avg salary");

# === Closures ===
sub make_range_check {
    my ($min, $max) = @_;
    return sub { return $_[0] >= $min && $_[0] <= $max; };
}
my $check = make_range_check(10, 20);
ok($check->(15), "closure in range");
ok(!$check->(25), "closure out of range");

# === Error Handling ===
eval {
    die {code => "E001", msg => "test error", detail => "something"};
};
ok(ref($@) eq "HASH", "die with hashref");
ok($@->{code} eq "E001", "error code");

# === String Processing ===
my $text = "The Quick Brown Fox Jumps Over The Lazy Dog";
my @words = split(/\s+/, $text);
my @long = grep { length($_) > 3 } @words;
ok(scalar(@long) == 5, "grep long words");
my $lower = join(" ", map { lc($_) } @words);
ok($lower =~ /^the quick/, "map lc");

# === File I/O ===
my $tmp = "/tmp/perla_rw_test_$$";
open(my $wfh, ">", $tmp);
print $wfh "line1\nline2\nline3\n";
close($wfh);
open(my $rfh, "<", $tmp);
my @lines;
while (my $line = <$rfh>) { chomp($line); push(@lines, $line); }
close($rfh);
unlink($tmp);
ok(scalar(@lines) == 3, "file I/O lines");
ok($lines[0] eq "line1", "first line");

# === @ARGV and %ENV ===
ok(ref(\@ARGV) eq "ARRAY", "ARGV");
ok(exists $ENV{PATH}, "ENV PATH");

# === Time ===
ok(time() > 1700000000, "time()");

# === OOP Inheritance ===
package Shape;
sub new { return bless({}, $_[0]); }
sub area { return 0; }

package Circle;
our @ISA = ('Shape');
sub new { return bless({r => $_[1]}, $_[0]); }
sub area { return 3.14159 * $_[0]->{r} * $_[0]->{r}; }

package main;
my $c = Circle->new(5);
ok($c->area() > 78, "circle area");
ok($c->isa("Shape"), "isa Shape");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All real-world tests passed!\n"; }
