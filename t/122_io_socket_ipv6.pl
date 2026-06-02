#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use IO::Socket::INET;

# IPv6 support: address resolution defaults to AF_UNSPEC so IPv6 literals and
# hostnames work transparently through IO::Socket::INET; host specs are parsed
# IPv6-aware (bracketed [::1]:port and bare ::1); sockport/peerport use
# sockaddr_storage. Note: real perl's IO::Socket::INET is IPv4-only, so it
# would skip this entirely — perla's native implementation is dual-stack.
#
# No fork here: a client connect completes via the listen backlog even before
# the server calls accept(), so the IPv6 client+server API can be exercised in
# a single process. (Full IPv6 data round-trips are covered manually; the
# fork-based pattern is in t/120.)

my $srv = IO::Socket::INET->new(
    LocalAddr => '::1', LocalPort => 0, Listen => 5, ReuseAddr => 1, Proto => 'tcp',
);

SKIP: {
    skip "no IPv6 loopback available", 6 unless $srv;

    is(ref($srv), "IO::Socket::INET", 'IPv6 server ref()');
    my $port = $srv->sockport;
    ok(defined($port) && $port > 0, "IPv6 server bound to ::1, sockport=$port");

    # Connect using the bracketed single-string form (exercises IPv6 parsing).
    my $cli = IO::Socket::INET->new("[::1]:$port");
    ok($cli, 'IPv6 client connect via [::1]:port form');
    is(ref($cli), "IO::Socket::INET", 'IPv6 client ref()');
    is($cli->peerport, $port, 'peerport() matches the server port (IPv6)');

    # The server accepts the queued connection.
    my $conn = $srv->accept;
    ok($conn, 'IPv6 server accept() returns the connection');

    $cli->close if $cli;
    $conn->close if $conn;
}

done_testing;
