my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# 1. Deep clone via recursive copy
sub deep_clone {
    my ($val) = @_;
    if (!defined($val)) { return undef; }
    if (ref($val) eq "HASH") {
        my %new;
        for my $k (keys %$val) {
            $new{$k} = deep_clone($val->{$k});
        }
        if (ref($val) ne "HASH") {
            # Blessed — preserve class
            return bless(\%new, ref($val));
        }
        return \%new;
    }
    if (ref($val) eq "ARRAY") {
        my @new;
        for my $item (@$val) {
            push(@new, deep_clone($item));
        }
        return \@new;
    }
    return $val;  # Scalar — copy by value
}

my $orig = {name => "Alice", scores => [90, 85], addr => {city => "NYC"}};
my $copy = deep_clone($orig);
$copy->{name} = "Bob";
$copy->{scores}[0] = 100;
$copy->{addr}{city} = "LA";
ok($orig->{name} eq "Alice", "deep clone: name unchanged");
ok($orig->{scores}[0] == 90, "deep clone: score unchanged");
ok($orig->{addr}{city} eq "NYC", "deep clone: addr unchanged");
ok($copy->{name} eq "Bob", "copy: name changed");
ok($copy->{addr}{city} eq "LA", "copy: addr changed");

# 2. Event system with multiple listeners
package EventBus;
sub new { return bless({listeners => {}}, $_[0]); }
sub on {
    my ($self, $event, $cb) = @_;
    $self->{listeners}{$event} = [] unless exists $self->{listeners}{$event};
    push(@{$self->{listeners}{$event}}, $cb);
    return $self;
}
sub emit {
    my ($self, $event, @args) = @_;
    my $handlers = $self->{listeners}{$event};
    if (defined($handlers)) {
        for my $cb (@$handlers) {
            $cb->(@args);
        }
    }
}
sub off {
    my ($self, $event) = @_;
    delete $self->{listeners}{$event};
}

package main;
my $bus = EventBus->new();
my @log;
$bus->on("msg", sub { push(@log, "handler1: " . $_[0]); });
$bus->on("msg", sub { push(@log, "handler2: " . $_[0]); });
$bus->emit("msg", "hello");
ok(scalar(@log) == 2, "event: 2 handlers");
ok($log[0] eq "handler1: hello", "handler 1");
ok($log[1] eq "handler2: hello", "handler 2");

$bus->off("msg");
@log = ();
$bus->emit("msg", "world");
ok(scalar(@log) == 0, "event: off removes handlers");

# 3. Builder pattern with validation
package FormBuilder;
sub new { return bless({fields => [], errors => []}, $_[0]); }
sub add_field {
    my ($self, $name, $type) = @_;
    push(@{$self->{fields}}, {name => $name, type => $type, value => undef});
    return $self;
}
sub set_value {
    my ($self, $name, $value) = @_;
    for my $f (@{$self->{fields}}) {
        if ($f->{name} eq $name) {
            $f->{value} = $value;
            return $self;
        }
    }
    return $self;
}
sub validate {
    my ($self) = @_;
    my @errors;
    for my $f (@{$self->{fields}}) {
        if ($f->{type} eq "required" && (!defined($f->{value}) || $f->{value} eq "")) {
            push(@errors, $f->{name} . " is required");
        }
        if ($f->{type} eq "email" && defined($f->{value}) && $f->{value} !~ /\@/) {
            push(@errors, $f->{name} . " must be a valid email");
        }
    }
    return @errors;
}

package main;
my $form = FormBuilder->new()
    ->add_field("name", "required")
    ->add_field("email", "email")
    ->set_value("name", "Alice")
    ->set_value("email", 'alice@example.com');
my @errs = $form->validate();
ok(scalar(@errs) == 0, "form valid");

my $form2 = FormBuilder->new()
    ->add_field("name", "required")
    ->add_field("email", "email")
    ->set_value("email", "not-an-email");
my @errs2 = $form2->validate();
ok(scalar(@errs2) == 2, "form errors: " . scalar(@errs2));

# 4. Simple state machine
package FSM;
sub new {
    my ($class, %args) = @_;
    return bless({
        state => $args{initial},
        transitions => $args{transitions},
    }, $class);
}
sub state { return $_[0]->{state}; }
sub trigger {
    my ($self, $event) = @_;
    my $key = $self->{state} . ":" . $event;
    if (exists $self->{transitions}{$key}) {
        $self->{state} = $self->{transitions}{$key};
        return 1;
    }
    return 0;
}

package main;
my $fsm = FSM->new(
    initial => "idle",
    transitions => {
        "idle:start" => "running",
        "running:pause" => "paused",
        "paused:resume" => "running",
        "running:stop" => "idle",
    },
);
ok($fsm->state() eq "idle", "fsm initial");
$fsm->trigger("start");
ok($fsm->state() eq "running", "fsm running");
$fsm->trigger("pause");
ok($fsm->state() eq "paused", "fsm paused");
$fsm->trigger("resume");
ok($fsm->state() eq "running", "fsm resumed");

# 5. Mini JSON serializer (handles nested)
sub json_encode {
    my ($val) = @_;
    if (!defined($val)) { return "null"; }
    if (ref($val) eq "HASH") {
        my @pairs;
        for my $k (sort keys %$val) {
            push(@pairs, "\"$k\":" . json_encode($val->{$k}));
        }
        return "{" . join(",", @pairs) . "}";
    }
    if (ref($val) eq "ARRAY") {
        my @items;
        for my $item (@$val) { push(@items, json_encode($item)); }
        return "[" . join(",", @items) . "]";
    }
    if ($val =~ /^-?\d+(\.\d+)?$/) { return $val; }
    return "\"$val\"";
}

my $json = json_encode({name => "Alice", age => 30, tags => ["admin", "user"]});
ok($json =~ /"name":"Alice"/, "json name");
ok($json =~ /"age":30/, "json age");
ok($json =~ /\["admin","user"\]/, "json array");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All advanced2 tests passed!\n"; }
