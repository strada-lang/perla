#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Perla-friendly tests: $~ applies to the next write regardless of
# handle. Each section restores $~ to empty so other sections start clean.

# 1. $~ runtime selection of format name on write
{
    open(FA, ">", "/tmp/perla_t79_a.out") or die $!;
    format A_FMT =
A: @<<<<
$_
.
    format B_FMT =
B: @<<<<
$_
.
    $~ = "A_FMT";
    $_ = "one";
    write FA;
    $~ = "B_FMT";
    $_ = "two";
    write FA;
    $~ = "";
    close FA;
    open(my $in, "<", "/tmp/perla_t79_a.out") or die;
    my $got = do { local $/; <$in> };
    close $in;
    unlink "/tmp/perla_t79_a.out";
    like($got, qr/A: one/, '$~ selects format by name (1)');
    like($got, qr/B: two/, '$~ selects format by name (2)');
}

# 2. write to bareword FH uses handle-named format by default
{
    open(MYWR, ">", "/tmp/perla_t79_c.out") or die $!;
    format MYWR =
W: @<<<<
$_
.
    for my $w (qw(alpha beta gamma)) {
        $_ = $w;
        write MYWR;
    }
    close MYWR;
    open(my $in, "<", "/tmp/perla_t79_c.out") or die;
    my $got = do { local $/; <$in> };
    close $in;
    unlink "/tmp/perla_t79_c.out";
    like($got, qr/W: alpha/, 'write FH wrote to bareword handle');
    like($got, qr/W: gamma/, 'write FH wrote multiple records');
}

# 3. $= pagination — TOP fires when lines_left exhausts
{
    open(PG, ">", "/tmp/perla_t79_b.out") or die $!;
    format PG_TOP =
==TOP==
.
    format PG =
@<<<
$_
.
    $~ = "PG";
    $^ = "PG_TOP";
    $= = 4;
    for my $w (qw(a b c d e f)) {
        $_ = $w;
        write PG;
    }
    $~ = "";
    $^ = "";
    $= = 60;
    close PG;
    open(my $in, "<", "/tmp/perla_t79_b.out") or die;
    my $got = do { local $/; <$in> };
    close $in;
    unlink "/tmp/perla_t79_b.out";
    my $n = () = $got =~ /==TOP==/g;
    cmp_ok($n, '>=', 2, 'TOP fires at least twice for 6 records at $==4');
}

# 4. $% page number visible in $print and TOP picture
{
    open(P4, ">", "/tmp/perla_t79_d.out") or die;
    format P4_TOP =
PAGE: @#
$%
.
    format P4 =
@<<<
$_
.
    $~ = "P4";
    $^ = "P4_TOP";
    $= = 3;
    for my $w (qw(a b c d e f g)) { $_ = $w; write P4; }
    $~ = ""; $^ = ""; $= = 60;
    close P4;
    open(my $in, "<", "/tmp/perla_t79_d.out") or die;
    my $got = do { local $/; <$in> };
    close $in; unlink "/tmp/perla_t79_d.out";
    like($got, qr/PAGE:\s+1\b/, '$% renders as 1 on first page');
    like($got, qr/PAGE:\s+3\b/, '$% renders as 3 on third page');
}

# 5. formline + $^A accumulator
{
    $^A = "";
    formline("@<<<<<<<<<<", "hello");
    formline("@>>>>>>>>>>", "world");
    like($^A, qr/hello\b/, 'formline left-justified');
    like($^A, qr/world\b/, 'formline right-justified');
    like($^A, qr/world\s*$/, '$^A ends with the right-justified output');
}

# 6. select() redirects bare write
{
    open(my $fh, ">", "/tmp/perla_t79_e.out") or die;
    my $old = select($fh);
    format STDOUT =
SEL: @<<<<
$_
.
    $_ = "via_select";
    write;
    select($old);
    close $fh;
    open(my $in, "<", "/tmp/perla_t79_e.out") or die;
    my $got = do { local $/; <$in> };
    close $in; unlink "/tmp/perla_t79_e.out";
    like($got, qr/SEL: via_s/, 'select() redirects bare write target');
}

# 7. Undefined-format die — open a FH whose name is never registered as
# a format, then write to it. perla and perl both error "Undefined format".
{
    open(NEVER_REGISTERED, ">", "/tmp/perla_t79_f.out") or die;
    eval { write NEVER_REGISTERED; };
    close NEVER_REGISTERED;
    unlink "/tmp/perla_t79_f.out";
    like($@, qr/Undefined format/, 'write on undefined format dies');
}

# 8. Block-scope `my` lexicals in format value lines — bridged via
# codegen-emitted sync helper that pushes the renamed C var into a
# mangled stash slot before each write. Also exercises Collect's
# rewrite of the format body's textual refs to match the renamed vars.
{
    my $price = 3.14159;
    my $qty = 42;
    open(LX, ">", "/tmp/perla_t79_g.out") or die;
    format LX =
@####.## @###
$price, $qty
.
    write LX;
    $price = 1.5;
    $qty = 7;
    write LX;
    close LX;
    open(my $in, "<", "/tmp/perla_t79_g.out") or die;
    my $got = do { local $/; <$in> };
    close $in;
    unlink "/tmp/perla_t79_g.out";
    like($got, qr/3\.14\s+42/, 'lex vars resolved on first write');
    like($got, qr/1\.50\s+7/, 'lex vars track updates between writes');
}

# 9. `write \$fh` — scalar var holding a filehandle.
{
    my $fh;
    open($fh, ">", "/tmp/perla_t79_h.out") or die;
    format STDOUT =
SV: @<<<<
$_
.
    $_ = "via_sv";
    write $fh;
    close $fh;
    open(my $in, "<", "/tmp/perla_t79_h.out") or die;
    my $got = do { local $/; <$in> };
    close $in;
    unlink "/tmp/perla_t79_h.out";
    like($got, qr/SV: via_/, 'write \$fh routes to the scalar handle');
}

done_testing();
