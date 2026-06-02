use strict;
use warnings;
use lib "perla/t/lib";
use MyApp::Model;
use MyApp::User;
use MyApp::Utils::StringUtils;

our $pass = 0;
our $fail = 0;
sub ok {
    my ($test, $name) = @_;
    if ($test) { $pass++; }
    else { $fail++; print "FAIL: " . $name . "\n"; }
}

# --- Test Model ---
my $m = MyApp::Model::new("MyApp::Model", id => 1);
$m->set("color", "red");
$m->set("size", "large");
ok($m->id() == 1, "model id");
ok($m->get("color") eq "red", "model get color");
ok($m->to_string() eq "Model#1{color=red, size=large}", "model to_string: " . $m->to_string());

# --- Test User (inherits from Model) ---
my $u = MyApp::User::new("MyApp::User", id => 42, name => "Alice", email => "alice@example.com");
ok($u->name() eq "Alice", "user name");
ok($u->email() eq "alice@example.com", "user email");
ok($u->id() == 42, "user id (inherited)");
ok($u->greeting() eq "Hello, Alice!", "user greeting");

# --- Test Utils ---
ok(MyApp::Utils::StringUtils::trim("  hello  ") eq "hello", "trim");
ok(length(MyApp::Utils::StringUtils::pad_right("hi", 10)) == 10, "pad_right");
ok(MyApp::Utils::StringUtils::repeat_str("ab", 3) eq "ababab", "repeat_str");

# --- Multiple models ---
my @users = ();
push(@users, MyApp::User::new("MyApp::User", id => 1, name => "Alice"));
push(@users, MyApp::User::new("MyApp::User", id => 2, name => "Bob"));
push(@users, MyApp::User::new("MyApp::User", id => 3, name => "Charlie"));

my @greetings = map { $_->greeting() } @users;
ok(join("; ", @greetings) eq "Hello, Alice!; Hello, Bob!; Hello, Charlie!", "map over users");

# Report
print "\nPassed: " . $pass . "\n";
print "Failed: " . $fail . "\n";
if ($fail == 0) { print "All module tests passed!\n"; }
