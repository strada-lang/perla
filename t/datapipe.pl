use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

package Pipeline;

sub new {
    my ($class, @data) = @_;
    return bless({ data => \@data }, $class);
}

sub from_array {
    my ($class, $arr) = @_;
    return bless({ data => $arr }, $class);
}

sub map_fn {
    my ($self, $fn) = @_;
    my @result = ();
    foreach my $item (@{$self->{data}}) {
        push(@result, $fn->($item));
    }
    return Pipeline::new("Pipeline", @result);
}

sub filter_fn {
    my ($self, $fn) = @_;
    my @result = ();
    foreach my $item (@{$self->{data}}) {
        if ($fn->($item)) { push(@result, $item); }
    }
    return Pipeline::new("Pipeline", @result);
}

sub reduce {
    my ($self, $fn, $init) = @_;
    my $acc = $init;
    foreach my $item (@{$self->{data}}) {
        $acc = $fn->($acc, $item);
    }
    return $acc;
}

sub first { return $_[0]->{data}[0]; }
sub last_item { my $len = scalar(@{$_[0]->{data}}); return $_[0]->{data}[$len - 1]; }
sub count { return scalar(@{$_[0]->{data}}); }
sub to_array { return @{$_[0]->{data}}; }

sub unique {
    my ($self) = @_;
    my @result = ();
    my %seen = ();
    foreach my $item (@{$self->{data}}) {
        my $key = "" . $item;
        if (!exists($seen{$key})) {
            push(@result, $item);
            $seen{$key} = 1;
        }
    }
    return Pipeline::new("Pipeline", @result);
}

sub group_by {
    my ($self, $fn) = @_;
    my %groups = ();
    foreach my $item (@{$self->{data}}) {
        my $key = $fn->($item);
        if (!exists($groups{$key})) { $groups{$key} = []; }
        push(@{$groups{$key}}, $item);
    }
    return \%groups;
}

package main;

my $p = Pipeline::new("Pipeline", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
ok($p->count() == 10, "count");

my $doubled = $p->map_fn(sub { return $_[0] * 2; });
ok($doubled->first() == 2, "map first");
ok($doubled->last_item() == 20, "map last");

my $evens = $p->filter_fn(sub { return $_[0] % 2 == 0; });
ok($evens->count() == 5, "filter count");

my $sum = $p->reduce(sub { return $_[0] + $_[1]; }, 0);
ok($sum == 55, "reduce sum");

# Chain
my $result = $p
    ->filter_fn(sub { return $_[0] > 3; })
    ->map_fn(sub { return $_[0] * $_[0]; })
    ->reduce(sub { return $_[0] + $_[1]; }, 0);
ok($result == 371, "chained: " . $result);

my $uniq = Pipeline::new("Pipeline", 1, 2, 2, 3, 3, 3, 4)->unique();
ok($uniq->count() == 4, "unique");

# Hash data pipeline
my @people = (
    { name => "Alice", age => 30, dept => "eng" },
    { name => "Bob", age => 25, dept => "sales" },
    { name => "Charlie", age => 35, dept => "eng" },
    { name => "Diana", age => 28, dept => "sales" },
    { name => "Eve", age => 32, dept => "eng" },
);

my $pp = Pipeline::from_array("Pipeline", \@people);

my @eng = $pp->filter_fn(sub { return $_[0]->{dept} eq "eng"; })->to_array();
ok(scalar(@eng) == 3, "eng count");

my @names = $pp->map_fn(sub { return $_[0]->{name}; })->to_array();
ok(scalar(@names) == 5, "names count");
ok($names[0] eq "Alice", "names first");

my $groups = $pp->group_by(sub { return $_[0]->{dept}; });
ok(scalar(@{$groups->{eng}}) == 3, "group eng");
ok(scalar(@{$groups->{sales}}) == 2, "group sales");

my $total_age = $pp->reduce(sub { return $_[0] + $_[1]->{age}; }, 0);
ok($total_age == 150, "total age: " . $total_age);

my $avg_age = int($total_age / $pp->count());
ok($avg_age == 30, "avg age");

# Chained filter + reduce
my $eng_avg = Pipeline::from_array("Pipeline", \@people)
    ->filter_fn(sub { return $_[0]->{dept} eq "eng"; })
    ->reduce(sub { return $_[0] + $_[1]->{age}; }, 0);
my $eng_count = Pipeline::from_array("Pipeline", \@people)
    ->filter_fn(sub { return $_[0]->{dept} eq "eng"; })
    ->count();
ok(int($eng_avg / $eng_count) == 32, "eng avg age");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All pipeline tests passed!\n"; }
