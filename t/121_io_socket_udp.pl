#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use IO::Socket::INET;

# UDP support: IO::Socket::INET with Proto => 'udp' creates a datagram socket
# (bind-only server, connect-for-default-peer client). Datagram I/O is via
# ->send(MSG [,FLAGS [,TO]]) and ->recv(BUF, LEN) — recv fills BUF in place
# and returns the sender's packed sockaddr.

my $srv = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
);
ok($srv, 'UDP server socket created (bind, no listen)');
is(ref($srv), "IO::Socket::INET", 'ref() is IO::Socket::INET');
my $port = $srv->sockport;
ok(defined($port) && $port > 0, "sockport returns a port ($port)");

my $tmp = "/tmp/perla_udp_test_$$";
unlink $tmp;

my $pid = fork();
defined($pid) or die "fork: $!";
if (!$pid) {
    my $cli = IO::Socket::INET->new(
        PeerAddr => '127.0.0.1',
        PeerPort => $port,
        Proto    => 'udp',
    );
    my $reply = '';
    if ($cli) {
        $cli->send("hello-udp");
        $cli->recv($reply, 1024);
    }
    if (open(my $out, '>', $tmp)) { print {$out} $reply; close $out; }
    exec($^X, '-e', '0');   # bypass inherited Test::More END block
    exit 0;
}

# Server: receive one datagram, reply to its sender.
my $buf = '';
my $from = $srv->recv($buf, 1024);
is($buf, "hello-udp", 'server recv() filled the buffer in place');
ok(defined($from) && length($from) > 0, 'recv() returned the sender address');
$srv->send("ack:$buf", 0, $from);
waitpid($pid, 0);

my $child_got = '';
if (open(my $in, '<', $tmp)) { local $/; $child_got = <$in>; close $in; }
unlink $tmp;
is($child_got, "ack:hello-udp", 'client recv() got the server reply (round trip)');

done_testing;
