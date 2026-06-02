#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native IO::Socket::SSL client (OpenSSL). Needs a TLS server, so it SKIPS
# when none is reachable. Point it at one with PERLA_TEST_SSL_HOST/PORT.
# The server is expected to send a line, then echo "echo:<input>".
use IO::Socket::SSL;

my $host = $ENV{PERLA_TEST_SSL_HOST} || "127.0.0.1";
my $port = $ENV{PERLA_TEST_SSL_PORT} || 14443;

my $c = IO::Socket::SSL->new(PeerHost => $host, PeerPort => $port, SSL_verify_mode => 0, Timeout => 5);
unless (defined $c) {
    plan skip_all => "no TLS server reachable ($host:$port)";
}

plan tests => 6;
ok($c->connected, "connected");
my $greeting = <$c>;                 # diamond read
ok(defined $greeting && length $greeting, "diamond <\$sock> read");

ok($c->print("PING\n"), "method print");      # method-form write
my $echo = <$c>;
like($echo, qr/PING/, "read echo of method print");

print $c "PONG\n";                   # function-form write (strada_print_fh hook)
my $echo2 = <$c>;
like($echo2, qr/PONG/, "read echo of function-form print");

ok($c->close, "close");
