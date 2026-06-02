my $pass = 0;
my $fail = 0;
sub ok { my ($t, $n) = @_; if ($t) { $pass++; } else { $fail++; print "FAIL: $n\n"; } }

# 1. Try::Tiny-like pattern
sub try_catch {
    my ($try, $catch) = @_;
    eval { $try->(); };
    if ($@) {
        return $catch->($@) if defined($catch);
        return undef;
    }
    return 1;
}

my $result = try_catch(
    sub { die "test error\n"; },
    sub { return "caught: " . $_[0]; },
);
chomp($result);
ok($result eq "caught: test error", "try_catch: $result");

# 2. Carp-like
sub croak { die join("", @_); }
sub carp { warn join("", @_); }

eval { croak("bad input"); };
ok($@ =~ /bad input/, "croak");

# 3. Moo-like accessor generation pattern
package MiniMoo;
sub new {
    my ($class, %args) = @_;
    return bless(\%args, $class);
}
sub has_attr {
    my ($class, $name, %opts) = @_;
    # In real Moo this installs accessors dynamically
    # Here we just verify the pattern
    return 1;
}

package User;
our @ISA = ('MiniMoo');
sub name {
    if (scalar(@_) > 1) { $_[0]->{name} = $_[1]; return $_[0]; }
    return $_[0]->{name};
}
sub email {
    if (scalar(@_) > 1) { $_[0]->{email} = $_[1]; return $_[0]; }
    return $_[0]->{email};
}
sub age {
    if (scalar(@_) > 1) { $_[0]->{age} = $_[1]; return $_[0]; }
    return $_[0]->{age};
}

package main;
my $user = User->new(name => "Alice", email => 'alice@example.com', age => 30);
ok($user->name() eq "Alice", "Moo-like get");
ok($user->email() =~ /alice/, "Moo-like email");
$user->name("Bob")->age(25);
ok($user->name() eq "Bob", "Moo-like chain set");
ok($user->age() == 25, "Moo-like age");

# 4. Dispatcher pattern (like Catalyst/Dancer routes)
package Dispatch;
sub new { return bless({routes => {}, before => [], after => []}, $_[0]); }
sub add_route {
    my ($self, $method, $path, $handler) = @_;
    $self->{routes}{"$method $path"} = $handler;
    return $self;
}
sub before_hook { push(@{$_[0]->{before}}, $_[1]); return $_[0]; }
sub after_hook { push(@{$_[0]->{after}}, $_[1]); return $_[0]; }
sub handle {
    my ($self, $method, $path, $ctx) = @_;
    $ctx = {} unless defined($ctx);
    # Run before hooks
    for my $hook (@{$self->{before}}) { $hook->($ctx); }
    # Dispatch
    my $key = "$method $path";
    if (exists $self->{routes}{$key}) {
        $ctx->{response} = $self->{routes}{$key}->($ctx);
    } else {
        $ctx->{response} = {status => 404};
    }
    # Run after hooks
    for my $hook (@{$self->{after}}) { $hook->($ctx); }
    return $ctx->{response};
}

package main;
my $d = Dispatch->new();
my @log;
$d->before_hook(sub { $_[0]->{start} = 1; });
$d->after_hook(sub { push(@log, "done:" . $_[0]->{response}{status}); });
$d->add_route("GET", "/", sub { return {status => 200, body => "Home"}; });
$d->add_route("GET", "/about", sub { return {status => 200, body => "About"}; });

my $res = $d->handle("GET", "/");
ok($res->{status} == 200, "dispatch home");
ok($log[0] eq "done:200", "after hook");

$res = $d->handle("GET", "/missing");
ok($res->{status} == 404, "dispatch 404");

# 5. Data validation
package Validator;
sub new { return bless({rules => []}, $_[0]); }
sub required {
    my ($self, $field) = @_;
    push(@{$self->{rules}}, {field => $field, type => "required"});
    return $self;
}
sub min_length {
    my ($self, $field, $len) = @_;
    push(@{$self->{rules}}, {field => $field, type => "min_length", param => $len});
    return $self;
}
sub validate {
    my ($self, $data) = @_;
    my @errors;
    for my $rule (@{$self->{rules}}) {
        my $val = $data->{$rule->{field}};
        if ($rule->{type} eq "required") {
            if (!defined($val) || $val eq "") {
                push(@errors, $rule->{field} . " is required");
            }
        }
        if ($rule->{type} eq "min_length") {
            if (defined($val) && length($val) < $rule->{param}) {
                push(@errors, $rule->{field} . " too short");
            }
        }
    }
    return @errors;
}

package main;
my $v = Validator->new()->required("name")->required("email")->min_length("name", 3);
my @errs = $v->validate({name => "Al", email => 'a@b.c'});
ok(scalar(@errs) == 1, "validator: " . scalar(@errs) . " error");
ok($errs[0] =~ /too short/, "validator msg");

my @errs2 = $v->validate({name => "", email => ""});
ok(scalar(@errs2) >= 2, "validator: " . scalar(@errs2) . " errors");

print "\nPassed: $pass\nFailed: $fail\n";
if ($fail == 0) { print "All CPAN pattern tests passed!\n"; }
