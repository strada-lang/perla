use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Event emitter
package EventEmitter;

sub new {
    my ($class) = @_;
    return bless({ handlers => {} }, $class);
}

sub on {
    my ($self, $event, $handler) = @_;
    if (!exists($self->{handlers}{$event})) {
        $self->{handlers}{$event} = [];
    }
    push(@{$self->{handlers}{$event}}, $handler);
    return $self;
}

sub emit {
    my ($self, $event, @args) = @_;
    if (exists($self->{handlers}{$event})) {
        foreach my $handler (@{$self->{handlers}{$event}}) {
            $handler->(@args);
        }
    }
    return $self;
}

sub off {
    my ($self, $event) = @_;
    delete $self->{handlers}{$event};
    return $self;
}

sub listener_count {
    my ($self, $event) = @_;
    if (exists($self->{handlers}{$event})) {
        return scalar(@{$self->{handlers}{$event}});
    }
    return 0;
}

# Middleware chain
package MiddlewareChain;

sub new {
    my ($class) = @_;
    return bless({ stack => [] }, $class);
}

sub add {
    my ($self, $handler) = @_;
    push(@{$self->{stack}}, $handler);
    return $self;
}

sub run {
    my ($self, $ctx) = @_;
    my @stack = @{$self->{stack}};
    my $i = 0;
    my $max = scalar(@stack);
    while ($i < $max) {
        my $handler = $stack[$i];
        my $result = $handler->($ctx);
        if (defined($result) && $result eq "stop") {
            return $ctx;
        }
        $i++;
    }
    return $ctx;
}

package main;

# Test EventEmitter
my $emitter = EventEmitter::new("EventEmitter");
our @log = [];

$emitter->on("data", sub { push(@log, "got:" . $_[0]); });
$emitter->on("data", sub { push(@log, "also:" . $_[0]); });
$emitter->on("error", sub { push(@log, "err:" . $_[0]); });

ok($emitter->listener_count("data") == 2, "listener count data");
ok($emitter->listener_count("error") == 1, "listener count error");

$emitter->emit("data", "hello");
$emitter->emit("data", "world");
$emitter->emit("error", "oops");

ok(scalar(@log) == 5, "event log count");
ok($log[0] eq "got:hello", "event 0");
ok($log[1] eq "also:hello", "event 1");
ok($log[4] eq "err:oops", "event 4");

$emitter->off("data");
ok($emitter->listener_count("data") == 0, "after off");

# Test middleware
my $chain = MiddlewareChain::new("MiddlewareChain");
$chain->add(sub { my ($ctx) = @_; $ctx->{method} = uc($ctx->{method}); return undef; });
$chain->add(sub { my ($ctx) = @_; $ctx->{processed} = 1; return undef; });

my $ctx = { method => "get", path => "/api" };
$chain->run($ctx);
ok($ctx->{method} eq "GET", "middleware uppercase");
ok($ctx->{processed} == 1, "middleware processed");

# Middleware stop
my $chain2 = MiddlewareChain::new("MiddlewareChain");
$chain2->add(sub { $_[0]->{step1} = 1; return undef; });
$chain2->add(sub { $_[0]->{step2} = 1; return "stop"; });
$chain2->add(sub { $_[0]->{step3} = 1; return undef; });

my $ctx2 = {};
$chain2->run($ctx2);
ok($ctx2->{step1} == 1, "step1 ran");
ok($ctx2->{step2} == 1, "step2 ran");
ok(!defined($ctx2->{step3}), "step3 skipped");

# Chained on + emit
my $bus = EventEmitter::new("EventEmitter");
our @msgs = [];
$bus->on("msg", sub { push(@msgs, $_[0]); })->emit("msg", "first")->emit("msg", "second");
ok(scalar(@msgs) == 2, "chained emit count");
ok($msgs[0] eq "first", "chained first");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All event tests passed!\n"; }
