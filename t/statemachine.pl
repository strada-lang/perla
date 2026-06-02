use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Finite state machine implementation
package FSM;

sub new {
    my ($class, %args) = @_;
    return bless({
        states      => $args{states} || {},
        current     => $args{initial} || "start",
        transitions => [],
    }, $class);
}

sub state    { return $_[0]->{current}; }

sub add_transition {
    my ($self, $from, $event, $to, $action) = @_;
    push(@{$self->{transitions}}, {
        from   => $from,
        event  => $event,
        to     => $to,
        action => $action,
    });
}

sub trigger {
    my ($self, $event) = @_;
    foreach my $t (@{$self->{transitions}}) {
        if ($t->{from} eq $self->{current} && $t->{event} eq $event) {
            my $old = $self->{current};
            $self->{current} = $t->{to};
            if (defined($t->{action})) {
                $t->{action}->($old, $event, $t->{to});
            }
            return 1;
        }
    }
    return 0;
}

sub can_trigger {
    my ($self, $event) = @_;
    foreach my $t (@{$self->{transitions}}) {
        if ($t->{from} eq $self->{current} && $t->{event} eq $event) {
            return 1;
        }
    }
    return 0;
}

package main;

# Build a traffic light FSM
my $light = FSM::new("FSM", initial => "red");

our @log = [];
my $logger = sub {
    my ($from, $event, $to) = @_;
    push(@log, $from . "->" . $to);
};

$light->add_transition("red", "timer", "green", $logger);
$light->add_transition("green", "timer", "yellow", $logger);
$light->add_transition("yellow", "timer", "red", $logger);

ok($light->state() eq "red", "initial state");
ok($light->can_trigger("timer") == 1, "can trigger timer");
ok($light->can_trigger("reset") == 0, "cannot trigger reset");

$light->trigger("timer");
ok($light->state() eq "green", "after first timer");

$light->trigger("timer");
ok($light->state() eq "yellow", "after second timer");

$light->trigger("timer");
ok($light->state() eq "red", "full cycle");

ok(scalar(@log) == 3, "log count");
ok($log[0] eq "red->green", "log entry 0");
ok($log[2] eq "yellow->red", "log entry 2");

# Run multiple cycles
for (my $i = 0; $i < 6; $i++) {
    $light->trigger("timer");
}
ok($light->state() eq "red", "after 6 more transitions");
ok(scalar(@log) == 9, "total log: " . scalar(@log));

# Build a door FSM
my $door = FSM::new("FSM", initial => "closed");
$door->add_transition("closed", "open", "opened", undef);
$door->add_transition("opened", "close", "closed", undef);
$door->add_transition("closed", "lock", "locked", undef);
$door->add_transition("locked", "unlock", "closed", undef);

ok($door->state() eq "closed", "door closed");
$door->trigger("lock");
ok($door->state() eq "locked", "door locked");
ok($door->can_trigger("open") == 0, "cant open locked");
$door->trigger("unlock");
ok($door->state() eq "closed", "door unlocked");
$door->trigger("open");
ok($door->state() eq "opened", "door opened");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All FSM tests passed!\n"; }
