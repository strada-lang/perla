my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# Deep inheritance
package Animal;
sub new { return bless({type => $_[1], sound => $_[2]}, $_[0]); }
sub describe { return $_[0]->{type} . " says " . $_[0]->{sound}; }

package Domestic;
our @ISA = ('Animal');
sub new { return bless({type => $_[1], sound => $_[2], owner => $_[3]}, $_[0]); }
sub owner { return $_[0]->{owner}; }

package Dog;
our @ISA = ('Domestic');
sub new { return $_[0]->SUPER::new("dog", "woof", $_[1]); }
sub fetch { return $_[0]->{type} . " fetches!"; }

package main;
my $dog = Dog->new("Alice");
ok($dog->describe() eq "dog says woof", "deep inherit");
ok($dog->owner() eq "Alice", "mid method");
ok($dog->isa("Animal"), "deep isa");

# Plugin architecture
package PluginHost;
sub new { return bless({plugins => []}, $_[0]); }
sub register {
    my ($self, $p) = @_;
    push(@{$self->{plugins}}, $p);
    $p->init($self) if $p->can("init");
    return $self;
}
sub run_hooks {
    my ($self, $hook, @args) = @_;
    my @results;
    for my $p (@{$self->{plugins}}) {
        if ($p->can($hook)) { push(@results, $p->$hook(@args)); }
    }
    return @results;
}

package LogPlugin;
sub new { return bless({log => []}, $_[0]); }
sub init { push(@{$_[0]->{log}}, "init"); }
sub on_request { return "logged:" . $_[1]; }

package main;
my $host = PluginHost->new();
my $logger = LogPlugin->new();
$host->register($logger);
my @results = $host->run_hooks("on_request", "test");
ok(scalar(@results) == 1, "plugin hooks");

# Inventory
my @inv = (
    {name => "Apple", qty => 50, price => 1},
    {name => "Banana", qty => 100, price => 2},
    {name => "Cherry", qty => 30, price => 3},
);
my $total = 0;
for my $i (@inv) { $total += $i->{qty} * $i->{price}; }
ok($total == 340, "inventory: $total");

my $best;
for my $i (@inv) { if (!defined($best) || $i->{price} > $best->{price}) { $best = $i; } }
ok($best->{name} eq "Cherry", "most expensive");

my @big = grep { $_->{qty} >= 50 } @inv;
ok(scalar(@big) == 2, "in stock");

# Template
my $html = "Hello {{name}}, you are {{age}}";
for my $k ("name", "age") {
    my $ph = "{{$k}}";
    my %vars = (name => "Alice", age => "30");
    my $idx = index($html, $ph);
    if ($idx >= 0) {
        $html = substr($html, 0, $idx) . $vars{$k} . substr($html, $idx + length($ph));
    }
}
ok($html =~ /Alice/, "template: $html");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All adv3 tests passed!\n"; }
