my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# 1. $$ref dereference
my $x = "hello";
my $ref = \$x;
ok($$ref eq "hello", "scalar deref: " . $$ref);

# 2. Hashref/arrayref truthiness
ok({}, "empty hashref truthy");
ok([], "empty arrayref truthy");
ok(!undef, "undef falsy");
ok(0 == 0, "zero");

# 3. Complex OOP — mini ORM
package Record;
sub new {
    my ($class, %data) = @_;
    return bless({data => \%data, dirty => {}}, $class);
}
sub get { return $_[0]->{data}{$_[1]}; }
sub set {
    my ($self, $key, $val) = @_;
    $self->{data}{$key} = $val;
    $self->{dirty}{$key} = 1;
    return $self;
}
sub is_dirty { return scalar(keys %{$_[0]->{dirty}}) > 0; }
sub dirty_fields { return keys %{$_[0]->{dirty}}; }
sub to_hash { return %{$_[0]->{data}}; }

package main;
my $rec = Record->new(name => "Alice", age => 30);
ok($rec->get("name") eq "Alice", "ORM get");
$rec->set("age", 31);
ok($rec->get("age") == 31, "ORM set");
ok($rec->is_dirty(), "ORM dirty");
my @dirty = $rec->dirty_fields();
ok(scalar(@dirty) == 1, "ORM dirty fields");

# 4. String builder
package StringBuilder;
sub new { return bless({parts => [], sep => $_[1] || ""}, $_[0]); }
sub append { push(@{$_[0]->{parts}}, $_[1]); return $_[0]; }
sub prepend { unshift(@{$_[0]->{parts}}, $_[1]); return $_[0]; }
sub to_string { return join($_[0]->{sep}, @{$_[0]->{parts}}); }
sub length { return length($_[0]->to_string()); }

package main;
my $sb = StringBuilder->new(", ");
$sb->append("Hello")->append("World")->prepend("Start");
ok($sb->to_string() eq "Start, Hello, World", "StringBuilder: " . $sb->to_string());

# 5. Config with defaults
package AppConfig;
sub new {
    my ($class, %defaults) = @_;
    return bless({config => \%defaults}, $class);
}
sub get {
    my ($self, $key, $default) = @_;
    if (exists $self->{config}{$key}) { return $self->{config}{$key}; }
    return $default;
}
sub set { $_[0]->{config}{$_[1]} = $_[2]; return $_[0]; }
sub merge {
    my ($self, %overrides) = @_;
    for my $k (keys %overrides) { $self->{config}{$k} = $overrides{$k}; }
    return $self;
}

package main;
my $cfg = AppConfig->new(host => "localhost", port => 8080, debug => 0);
ok($cfg->get("host") eq "localhost", "config get");
ok($cfg->get("missing", "default") eq "default", "config default");
$cfg->merge(port => 9090, debug => 1);
ok($cfg->get("port") == 9090, "config merge");

# 6. Iterator pattern
package ArrayIter;
sub new {
    my ($class, @items) = @_;
    return bless({items => \@items, pos => 0}, $class);
}
sub has_next { return $_[0]->{pos} < scalar(@{$_[0]->{items}}); }
sub next {
    my $self = $_[0];
    my $val = $self->{items}[$self->{pos}];
    $self->{pos}++;
    return $val;
}
sub reset { $_[0]->{pos} = 0; }

package main;
my $it = ArrayIter->new("a", "b", "c");
my @collected;
while ($it->has_next()) { push(@collected, $it->next()); }
ok(join(",", @collected) eq "a,b,c", "iterator");
$it->reset();
ok($it->has_next(), "iterator reset");

# 7. File operations
my $tmpfile = "/tmp/perla_practical_$$";
open(my $fh, ">", $tmpfile);
for my $i (1..5) {
    print $fh "line $i\n";
}
close($fh);

# Count lines
open(my $rfh, "<", $tmpfile);
my $lc = 0;
while (my $line = <$rfh>) { $lc++; }
close($rfh);
unlink($tmpfile);
ok($lc == 5, "file line count: $lc");

# 8. Complex data transformation
my @students = (
    {name => "Alice", scores => [90, 85, 95]},
    {name => "Bob", scores => [80, 75, 85]},
    {name => "Carol", scores => [95, 90, 100]},
);
my @report;
for my $s (@students) {
    my $total = 0;
    for my $g (@{$s->{scores}}) { $total += $g; }
    my $avg = int($total / scalar(@{$s->{scores}}));
    push(@report, $s->{name} . ":" . $avg);
}
ok(join(", ", @report) eq "Alice:90, Bob:80, Carol:95", "student report: " . join(", ", @report));

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All practical tests passed!\n"; }
