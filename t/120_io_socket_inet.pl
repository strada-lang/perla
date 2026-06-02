#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use IO::Socket::INET;

# perla implements IO::Socket::INET natively (the real .pm builds on core
# socket()/connect(), which perla lacks). Exercise a full client<->server
# round trip on loopback using fork: parent is the server, child the client.
# The child writes its result to a temp file, then closes STDOUT (so its
# Test::More END block can't emit a second TAP plan) and exits.

my $srv = IO::Socket::INET->new(
    LocalHost => '127.0.0.1',
    LocalPort => 0,            # ephemeral port
    Listen    => 5,
    ReuseAddr => 1,
    Proto     => 'tcp',
);
ok($srv, 'server socket created (Listen)');
is(ref($srv), "IO::Socket::INET", 'ref() is IO::Socket::INET');
my $port = $srv->sockport;
ok(defined($port) && $port > 0, "sockport returns a port ($port)");

my $tmp = "/tmp/perla_sock_test_$$";
unlink $tmp;

my $pid = fork();
defined($pid) or die "fork: $!";
if (!$pid) {
    my $cli = IO::Socket::INET->new(
        PeerAddr => '127.0.0.1',
        PeerPort => $port,
        Proto    => 'tcp',
    );
    my $reply = '';
    if ($cli) {
        print $cli "ping\n";
        $reply = <$cli>;
        $reply = '' unless defined $reply;
        close $cli;
    }
    if (open(my $out, '>', $tmp)) {
        print {$out} $reply;
        close $out;
    }
    # exec a no-op so the child's process image is replaced and it never runs
    # the inherited Test::More END block (which would emit a second TAP plan).
    exec($^X, '-e', '0');
    exit 0;
}

# Parent: accept one connection, echo a reply.
my $conn = $srv->accept;
ok($conn, 'server accepted a connection');
my $line = <$conn>;
is($line, "ping\n", 'server received client message');
print $conn "pong:$line";
close $conn;
waitpid($pid, 0);

my $child_got = '';
if (open(my $in, '<', $tmp)) {
    local $/;
    $child_got = <$in>;
    close $in;
}
unlink $tmp;
is($child_got, "pong:ping\n", 'client received the server reply (round trip)');

done_testing;
