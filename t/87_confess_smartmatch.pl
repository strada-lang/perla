#!/usr/bin/perl
use warnings;
use Test::More;
use Carp qw(confess);

# --- Carp::confess includes the surrounding eval frame in the trace.
{
    sub d_inner { confess "boom" }
    sub d_mid   { d_inner() }
    sub d_top   { d_mid() }
    eval { d_top() };
    my $msg = $@;
    like($msg, qr/boom at /, "confess starts with msg and at-location");
    like($msg, qr/main::d_inner\(\) called at/, "deep frame named");
    like($msg, qr/main::d_mid\(\) called at/,   "mid frame named");
    like($msg, qr/main::d_top\(\) called at/,   "top frame named");
    like($msg, qr/eval \{\.\.\.\} called at/,   "eval pseudo-frame present");
}

# --- Smartmatch on common forms.
{
    no warnings 'experimental::smartmatch';
    my @a = (1, 2, 3, 4);
    ok( (3 ~~ @a), "scalar in array — match");
    ok(!(5 ~~ @a), "scalar in array — no match");

    my %h = (apple => 1, pear => 2);
    ok( ("apple" ~~ %h), "key in hash — match");
    ok(!("grape" ~~ %h), "key in hash — no match");

    my $x;
    ok( ($x ~~ undef), "undef RHS — undef LHS matches");
    $x = 5;
    ok(!($x ~~ undef), "undef RHS — defined LHS does not match");

    ok( ("hi" ~~ qr/h/),  "regex RHS — match");
    ok(!("hi" ~~ qr/z/),  "regex RHS — no match");

    my $cb = sub { $_[0] > 10 };
    ok( (42 ~~ $cb), "code ref RHS — truthy");
    ok(!(5  ~~ $cb), "code ref RHS — falsy");
}


# --- next::method walks C3 linearisation across a diamond regardless of
# the originating package's declared MRO.
{
    package M_A;
    sub new   { bless {}, shift }
    sub greet { "A" }

    package M_B;
    our @ISA = ('M_A');
    sub greet { "B>" . shift->next::method }

    package M_C;
    our @ISA = ('M_A');
    sub greet { "C>" . shift->next::method }

    package M_D;
    our @ISA = ('M_B', 'M_C');
    sub greet { "D>" . shift->next::method }

    package main;
    is(M_D->new->greet, "D>B>C>A",
       "next::method C3 across diamond (default-DFS classes)");
}


# --- Block-scoped my-var fires DESTROY at block exit even when the
# block contains a sub that does NOT reference the var. The previous
# heuristic ("any sub at all in the block disables cleanup") pinned
# the blessed object to global destruction, breaking RAII patterns
# like `{ package X; sub DESTROY {...}; my $o = bless {}, "X"; }`.
{
    package D_target;
    our $destroy_count = 0;
    sub DESTROY { $destroy_count++ }

    package main;

    # Sub in the block does NOT reference $o — block-exit decref runs.
    {
        package D_target;
        sub DESTROY { $D_target::destroy_count++ }
        my $o = bless {}, "D_target";
    }
    is($D_target::destroy_count, 1,
       "DESTROY fires at block exit when inner sub doesn't capture the var");
}


# --- $@ supports plain assignment and ||= / //=. DBI.pm's install_method
# uses `$@ ||= "$driver_class->driver didn't return a handle"` — the read
# path for $@ emits a lazy-init statement expression that is not a C lvalue,
# so the standard compound-assign expansion failed to compile.
{
    $@ = "had error";
    $@ ||= "fallback";
    is($@, "had error", "\$\@ ||= keeps existing value");
    $@ = "";
    $@ ||= "fallback";
    is($@, "fallback", "\$\@ ||= sets fallback when empty");
    $@ //= "still set";
    is($@, "fallback", "\$\@ //= no-op when defined");
}


# --- push/unshift flatten a parenthesized list arg. Perl's parens here
# are list grouping, not scalar comma — `push @arr, (5, 6)` is identical
# to `push @arr, 5, 6`. perla's fast path correctly excluded N_ANON_ARRAY,
# but the general path then evaluated `(5, 6)` as a scalar (returning
# last element / undef under want_list=-1) and the extra values were
# dropped.
{
    my @a = (3, 4);
    push @a, (5, 6);
    is("@a", "3 4 5 6", "push \@a, (5, 6) flattens parens");

    my @b = (3, 4);
    push @b, (5, 6, 7);
    is("@b", "3 4 5 6 7", "push \@a, (5, 6, 7) flattens 3-elem parens");

    my @c = (3, 4);
    unshift @c, (1, 2);
    is("@c", "1 2 3 4", "unshift \@a, (1, 2) flattens parens");
}

# --- Recursive method dispatched through StradaStackArgs1 used to leave
# a STACK pointer in the cycle collector's cc_roots. At process exit
# the final sweep dereferenced the long-gone stack frame and SIGSEGV'd.
# Regression: any tree DFS plus a later recursive call would crash.
{
    package T87;
    sub new   { bless { c => [] }, $_[0] }
    sub addc  { push @{$_[0]->{c}}, $_[1]; $_[0] }
    sub df {
        my ($self) = @_;
        my @order;
        for my $c (@{$self->{c}}) { push @order, $c->df(); }
        return (@order, "leaf");
    }
    sub myrec { my $n = shift; return if $n <= 0; T87::myrec($n - 1); }

    package main;
    my $root = T87->new->addc(T87->new->addc(T87->new))->addc(T87->new);
    my @r = $root->df;
    is(scalar(@r), 4, "recursive method DFS returns expected count");
    T87::myrec(5);
    pass("recursion after \$root->df() completes without process-exit SIGSEGV");
}


# --- Array slice assignment with a list-producing index expression.
# The slice-assign codegen used to only flatten N_RANGE/N_ARRAY_VAR/
# N_DEREF_ARRAY indices; a range still emitted the flip-flop branch
# when want_list wasn't list at the gen-time of the index, so
# `@z[1..3] = LIST` silently no-op'd (the flip-flop returned a single
# bool and strada_deref_array(bool) was NULL). Calls/maps/reverses
# also fell through to the scalar branch and indexed at one slot.
{
    my @z = (0, 0, 0, 0, 0);
    @z[1..3] = (10, 20, 30);
    is("@z", "0 10 20 30 0", "\@z[1..3] = LIST assigns range slice");

    @z = (0, 0, 0, 0, 0);
    @z[reverse(1..3)] = (10, 20, 30);
    is("@z", "0 30 20 10 0", "\@z[reverse(1..3)] = LIST assigns call-result slice");

    @z = (0, 0, 0, 0, 0, 0);
    @z[map { $_ * 2 } 0..2] = ('a', 'b', 'c');
    is("@z", "a 0 b 0 c 0", "\@z[map ...] = LIST assigns mapped slice");
}


# --- Anonymous sub inside `my X = do { ... }` used to emit its body
# twice ("redefinition of perla_sub_main___perla_anon_N" from gcc).
# Cause: main body codegen ran first (which named the anon sub and
# pushed it to $cg->{anon_subs}). The subsequent hoist pass then
# walked the AST and saw N_SUB with name defined — gen_sub_def
# emitted body #1. Then the anon_subs loop emitted body #2.
# Fix: skip __perla_anon_N synthetic names in the hoist pass.
{
    my $iter = do {
        my @data = (10, 20, 30);
        my $i = 0;
        sub { return if $i >= @data; return $data[$i++]; };
    };
    my @collected;
    while (defined(my $v = $iter->())) { push @collected, $v; }
    is(scalar(@collected), 3, "iterator anon sub in do {} compiles + runs");
    is("@collected", "10 20 30",  "iterator produces all values");
}


# --- Outer `$X->{...}->{$k}` style access used to over-decref the
# inner hash on every read. Cause: the inner is N_ARROW_HASH /
# N_HASH_ELEM which gets routed through _gen_autoviv_hash, returning
# a BORROWED pointer to the stored hash. But the outer access set
# `__ahx_obj_owned = 1` for those AST types (the original aa4d4a29
# fix was scoped only to N_ARRAY_ELEM safety-incref), so it emitted
# `strada_decref(__o_orig)` on the borrowed pointer — and after a
# few accesses the storage was freed underneath the program.
#
# Surface form: dispatch tables stored on the invocant
# (`my $svc = S->new; $svc->run("a"); $svc->run("b")`) returned
# "unknown: b" because the second `$self->{actions}` lookup found
# the hash already torn down by the first call's over-decref.
{
    package SR_Service;
    sub new { bless { actions => {} }, shift }
    sub register { my ($s, $n, $cb) = @_; $s->{actions}{$n} = $cb; $s }
    sub run {
        my ($s, $n, @args) = @_;
        my $cb = $s->{actions}{$n} or return "missing:$n";
        $cb->(@args);
    }

    package main;
    my $svc = SR_Service->new
        ->register("greet", sub { "G:$_[0]" })
        ->register("add",   sub { $_[0] + $_[1] });
    is($svc->run("greet", "X"), "G:X", "dispatch table call #1");
    is($svc->run("add", 3, 4), 7,      "dispatch table call #2 (was over-decref'd)");
    is($svc->run("greet", "Y"), "G:Y", "dispatch table call #3 still works");
}


# --- `@x = LIST` inside a closure used to lose the value via UAF.
# The codegen emitted `v_x = strada_new_array(); … ; v_x` returning
# v_x without incref. When v_x mapped to a captured cell (closure),
# the caller's discard of `__void_rv` decreffed it to 0 — freeing
# the just-assigned array. The cell then held a dangling pointer.
# Sibling closures reading the same cell returned empty / garbage.
{
    sub make_box {
        my @x = (1, 2, 3, 4);
        return {
            get    => sub { @x },
            filter => sub { @x = (5, 6); },
        };
    }
    my $m = make_box();
    $m->{filter}->();
    my @r = $m->{get}->();
    is(scalar(@r), 2, "closure \@x = LIST persists across siblings — count");
    is("@r", "5 6",   "closure \@x = LIST persists across siblings — values");
}


# --- Same closure UAF for `%h = LIST` (hash analogue of the @arr fix
# above). The untied hash-assign return path emits `__h_result = v_h`
# without an incref — caller's discard freed it under the cell.
{
    sub make_hbox {
        my %h = (a => 1, b => 2);
        return {
            keys_in => sub { join(",", sort keys %h) },
            wipe    => sub { %h = (x => 10, y => 20); },
        };
    }
    my $m = make_hbox();
    $m->{wipe}->();
    is($m->{keys_in}->(), "x,y", "closure %h = LIST persists across siblings");
}

# --- Scalar reassign `$x = $y` for a borrowed RHS used to leak the
# old reference AND dangle the new one. The bare `v_x = __asn_new`
# emit didn't decref the old value (leak) and didn't incref the new
# value when borrowed. Sub-exit cleanup (`if (v_x) decref(v_x)`)
# then over-decref'd and the SV got freed under any other holder
# (e.g. a hash slot that stored the same pointer). Concrete victim:
# `$cur = $next` linked-list construction — `\$list->{next}->{value}`
# returned undef after sub return because nodes were freed at exit.
{
    package SR_DLL;
    sub new { bless { value => $_[1], next => undef }, $_[0] }
    sub from_list {
        my ($class, @vals) = @_;
        my $head = $class->new(shift @vals);
        my $cur = $head;
        while (@vals) {
            my $next = $class->new(shift @vals);
            $cur->{next} = $next;
            $cur = $next;       # ← scalar reassign with borrowed RHS
        }
        return $head;
    }
    sub values_ {
        my $head = shift;
        my @r;
        my $cur = $head;
        while ($cur) {
            push @r, $cur->{value};
            $cur = $cur->{next};
        }
        return @r;
    }

    package main;
    my $list = SR_DLL->from_list(10, 20, 30, 40, 50);
    is(join(",", $list->values_), "10,20,30,40,50",
       "linked-list \$cur = \$next reassign preserves nodes");
}


# --- Symbolic deref `\${\$i}` where \$i is a number (or pure-digit
# string) used to return undef because perla short-circuited
# tagged ints to undef before reaching capture-var lookup. perl's
# `\${\$i}` for numeric \$i reads the regex capture global \$N
# (the symbolic-ref-to-capture idiom seen in dispatch-table /
# route-matcher code).
{
    "hello world" =~ /(\w+) (\w+)/;
    my @captured;
    no strict 'refs';
    for my $i (1..2) {
        push @captured, "${$i}";
    }
    is("@captured", "hello world",
       "\${\\\$i} (tagged-int) reads regex capture \$N");

    my $j = "1";
    is(${$j}, "hello",
       "\${\\\$j} where \$j is pure-digit string reads \$N");
}

done_testing();
