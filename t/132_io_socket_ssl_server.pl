#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# Native IO::Socket::SSL server: new(Listen, SSL_cert_file, SSL_key_file) +
# ->accept (SSL_accept). Self-contained: forks a server child and connects to
# it as a native SSL client in the parent. Needs openssl to make a throwaway
# cert; SKIPs if that isn't available.
use IO::Socket::INET;
use IO::Socket::SSL;

my $cert = "/tmp/perla_t132_$$.crt";
my $key  = "/tmp/perla_t132_$$.key";
my $rc = system("openssl req -x509 -newkey rsa:2048 -keyout $key -out $cert " .
                "-days 1 -nodes -subj /CN=localhost >/dev/null 2>&1");
unless ($rc == 0 && -s $cert && -s $key) {
    plan skip_all => "openssl not available to generate a test cert";
}

# Pick a free port dynamically rather than a fixed/PID-derived one: bind an
# ephemeral TCP socket (LocalPort => 0), read back the OS-assigned port, close
# it, and reuse that number for the SSL server. Avoids collisions with a port a
# stale instance is holding (which used to make the server child hang in accept
# and orphan past the harness timeout).
sub free_port {
    my $s = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => 0,
        Listen => 1, ReuseAddr => 1, Proto => "tcp") or return 0;
    my $p = $s->sockport;
    $s->close;
    return $p;
}
my $port = free_port();
unless ($port) { plan skip_all => "could not find a free port"; }

my $pid = fork();
if (!defined $pid) { plan skip_all => "fork failed"; }

if ($pid == 0) {
    # child: TLS server, accept one connection, echo a line back. Guard accept()
    # with an alarm so a no-show client can never wedge the child forever.
    my $srv = IO::Socket::SSL->new(LocalAddr => "127.0.0.1", LocalPort => $port,
        ReuseAddr => 1, Listen => 5, SSL_cert_file => $cert, SSL_key_file => $key);
    if ($srv) {
        local $SIG{ALRM} = sub { exec($^X, "-e", "0"); };
        alarm(10);
        my $cli = $srv->accept;
        if ($cli) {
            my $line = $cli->getline;
            $cli->print("echo:$line");
            $cli->close;
        }
        $srv->close;
    }
    exec($^X, "-e", "0");   # exit child without running END/Test::More teardown
}

# parent: give the server a moment to bind, then connect as a TLS client
plan tests => 3;
select(undef, undef, undef, 0.7);
my $c = IO::Socket::SSL->new(PeerHost => "127.0.0.1", PeerPort => $port,
    SSL_verify_mode => 0, Timeout => 5);
ok(defined $c, "client connected to native SSL server");
SKIP: {
    skip "no connection", 2 unless defined $c;
    $c->print("hello\n");
    my $reply = <$c>;
    like($reply, qr/^echo:/,   "server echoed (TLS round-trip)");
    like($reply, qr/hello/,    "echo carried the payload");
    $c->close;
}
kill("TERM", $pid);   # never orphan the server child, even if it's mid-accept
waitpid($pid, 0);
unlink $cert, $key;
done_testing;
