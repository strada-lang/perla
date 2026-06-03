# Coding in Strada — working reference for the perla compiler

perla itself is written in **Strada** (`lib/Perla/**/*.strada`, runtime in C under
`runtime/`). This file is the practical "how do I write correct Strada" cheat sheet,
distilled from actually working on the perla codegen. Read `~/p/strada/CLAUDE.md` and
`~/p/strada/CLAUDE_REFERENCE.md` for the full language; this file is the high-frequency
subset plus the traps that actually bit us.

---

## 0. Build / test loop (do this, in this order)

```bash
# perla MUST build against the DEV strada runtime, NOT the installed /usr/local one.
# The installed runtime is stale (lacks the substr non-UTF8 fast path) → 25-min
# PublicSuffix quadratic-lex hangs. Always:
cd ~/p/perla && make STRADA_DIR=/home/mflickin/p/strada      # full, -O2 (committed builds)
cd ~/p/perla && make DEV=1 STRADA_DIR=/home/mflickin/p/strada # fast iterate (no -O2)

# Suite — must stay green (currently 159/159). Never commit a regression.
cd ~/p/perla && ./t/run_tests.sh
cd ~/p/perla && ./t/run_tests.sh --vm        # VM backend

# Compare any behavior against REAL perl:
/opt/bzperl/bin/perl script.pl
~/p/perla/perla -o /tmp/x script.pl && /tmp/x
```

**The build does NOT auto-recompile on a runtime-C change** and the `.strada` →
`Combined.strada` → `Combined.c` concat can silently reuse stale intermediates. If a
source edit "isn't taking effect," confirm with a `grep` for a unique string from your
edit inside `perla` is impossible (it's a binary) — instead `touch` the edited `.strada`,
`make` again, and check the build actually re-ran cc1 on Combined.c. **Verify the edit is
in the source on disk** (`grep -n 'my unique marker' lib/Perla/.../X.strada`) before
blaming codegen — half my "the fix didn't work" moments were the edit never landing or a
`git checkout` during an unrelated revert clobbering it.

---

## 1. Syntax you'll actually type

```strada
func name(scalar $a, int $n) int { ... }    # types optional; sigil sets default
func name { my $x = shift; ... }            # no-parens → implicit @_, like a Perl sub
my $f = fn ($x) { return $x * 2; };          # fn === func; closures capture by REFERENCE
my scalar $x = 42;  my array @a = (1,2,3);  my hash %h = ("k" => 1);
```

- `$` scalar (and element access `$a[0]`, `$h{"k"}`), `@` whole-array, `%` whole-hash.
- **No `elsif`-only world:** `elsif` and `else if` both work. `unless`/`until` exist.
- String ops: `.` concat, `x` repeat, `eq/ne/lt/gt/cmp` stringwise, `==/<=>` numeric.
- `//` defined-or, `||`/`&&` return the value (not a bool).
- `foreach (@a) { say($_); }` — implicit `$_`.
- Statement modifiers: `return 0 unless $ok;`  `say($x) if $v;`
- Ranges `0..5`, slices `@a[0,2,4]`, `@h{"x","y"}`.
- Ternary `COND ? A : B`. No `? :`-chains gotchas beyond Perl's.

### Declaring vs using sigils
`my $x` then refer to it as `$x`. Array element write: `$a[3] = ...`. Whole array ops
(`push`, `@a = (...)`, `scalar(@a)`) use `@a`. **`scalar(@a)` is the length**; `$n = @a`
in scalar context is the length too.

---

## 2. The traps that actually cost time

### 2a. Comparing an AST node to a string (the `$_[N]` bug)
AST nodes are **hash refs** (`{ "type" => N_..., ... }`). A field like `$node->{"array"}`
holds *another node hashref*, not a name string. Writing
`$node->{"array"} eq "_"` is comparing a hashref's stringification to `"_"` — **always
false**, silently. To test "is this `$_[N]` (element access on `@_`)":

```strada
if ($t == Perla::AST::N_ARRAY_ELEM() && defined($node->{"array"})
    && ref($node->{"array"}) eq "HASH"
    && $node->{"array"}->{"type"} == Perla::AST::N_SCALAR_VAR()
    && defined($node->{"array"}->{"name"}) && $node->{"array"}->{"name"} eq "_") { ... }
```

**Rule:** before `eq`/`ne` on an AST field, ask "is this field a child node or a leaf
scalar?" Leaves (`name`, `op`, `value`) are strings/ints; structural fields
(`array`, `object`, `left`, `right`, `body`, `args`, `elems`, `init`, `ref`) are
nodes or arrays-of-nodes. `ref($x) eq "HASH"` / `ref($x) eq "ARRAY"` guards everything.

### 2b. Node type constants are FUNCTION CALLS
`Perla::AST::N_ARRAY_ELEM()` — with parens. They're enum-ish funcs, not bare constants.
`$node->{"type"} == Perla::AST::N_CALL()`. Forgetting parens won't compare right.

### 2c. `scalar(@{$node->{"args"}})` for arg counts
`args`/`elems` are array refs. Count with `scalar(@{$node->{"args"}})`; iterate with
`for my $a (@{$node->{"args"}}) { ... }` or index `$node->{"args"}->[0]`. Always
`defined($node->{"args"})` first — many nodes omit empty list fields.

### 2d. Owned vs borrowed StradaValue in codegen (the #1 leak source)
When you emit C that calls a runtime function with an argument that might be a **hash
access** (`$h{"k"}`, `$h->{"k"}` → `strada_hv_fetch_owned`, OWNED), you must wrap it:

```strada
if ($cg->{"cleanup_enabled"} == 1 && needs_temp_cleanup($cg, $arg) == 1) {
    emit($cg, "({ StradaValue *__tmp = "); gen_expression($cg, $arg);
    emit($cg, "; RET __res = c_fn(__tmp); strada_decref(__tmp); __res; })");
} else {
    emit($cg, "c_fn("); gen_expression($cg, $arg); emit($cg, ")");
}
```

`needs_temp_cleanup()` and the call emitter MUST resolve the function name the **same
way** (same mangling + package-prefixed fallback) or owned returns from same-package
unqualified calls in non-`main` packages leak. **Test leak fixes in a non-`main`
package** — `main` doesn't exercise the mangle/fallback path. Run
`~/p/strada/t/leak_tests/run_leak_tests.sh` for strada; for perla, valgrind a small `.pl`.

### 2e. `strada_to_str()` allocates — free it
In `__C__` blocks: `char *s = strada_to_str(v); ...; free(s);`. Never nest it inside a
call arg. `strada_to_int/num()` return plain values, no free.

### 2f. Tagged ints are odd pointers — never touch `->type` blind
Any `StradaValue*` may be a tagged int (`STRADA_IS_TAGGED_INT(sv)`). Guard before
`sv->type`/`->value`/`->refcount`. Use `strada_to_int/str/num()` which handle it.

### 2g. `calloc` structs that are incrementally initialized
If you `malloc` a runtime struct and only set some fields, the unset fields are garbage
and `strada_free_value`'s branches read them (e.g. `cl->prototype`). Use `calloc`. Two
real crashes (StradaClosure.prototype, PerlStash.mro_c3) came from this; perla's SIGSEGV
handler mislabels them "stack overflow (likely deep recursion)."

### 2h. `_take` variants when creating-then-storing
`strada_hash_set_take(hv, k, strada_new_str("v"))` not `strada_hash_set(...)` — the
plain form leaves refcount 2. Same for `strada_array_push_take`.

---

## 3. Codegen mental model (perla-specific)

- `gen_expression($cg, $node)` emits C for an expression; `gen_statement` for a stmt.
- `emit($cg, "...")` appends C text. `$cg` is the codegen context hashref — holds
  `functions` (symbol table), `cleanup_enabled`, current package, etc.
- `$cg->{"functions"}->{$c_name}` is the compile-time symbol table. **Predicates that
  consult it (cleanup? owned-return? incref?) MUST use the same name resolver as the
  call emitter** (`gen_call`) — try `$c_name` then `<c_pkg>_<c_name>` for unqualified
  calls in non-`main` packages. Divergence = silent per-statement leaks (commit
  `b5f48978` in strada: every `my $x = N;` leaked ~74 blocks).
- `__perla_want_list` (a runtime int the emitted C reads) selects list vs scalar context
  for context-sensitive nodes (N_RANGE → flip-flop vs index array, `@h`/`%h` → count vs
  container). When emitting index/slice subexprs that must yield a list, save/restore
  `want_list=1` around them. Do **not** blanket-force want_list=1 on all args of a
  builtin — that regressed 138/159 suite tests once (the `join` attempt). Scope it.
- `__direct` calling convention (`Subs.strada`): subs whose params are detected
  (`analyze_sub_params` in `Collect.strada`) get peeled-param entry points; `perla_at_`
  (the `@_` array) is rebuilt from the params. **A sub that reads `$_[N]` or bare
  `shift`/`pop` after the param run must NOT be peeled** — `body_uses_at_underscore`
  (`Subs.strada`) is the gate; see 2a for the bug class it guards.

---

## 4. Runtime-C side (`runtime/perla_stash.c`, `strada_runtime.c`)

- Register a native sub: `perla_code_set("Pkg::name", fn)` or
  `perla_code_set_protected(...)` — **protected survives a loaded `.pm.o` override**.
  Use protected when a baked `.pm.o` would otherwise shadow your native impl
  (Config::FETCH needed this).
- `__C__ { ... }` blocks in `.strada` drop straight into C; variables are
  `StradaValue*`. Same ownership rules as §2.
- The XSLoader "native-lie" allowlist (`perla_xsloader.c` ~line 331): modules perla
  backs natively where a failed XS bootstrap must be non-fatal. Add a module here when
  you implement its XS surface in C.
- Parser compile-time native-skip list (`Parser.strada` ~1962): `use Errno`,
  `FFI::Platypus`, `Math::BigInt`, IO::Compress are dropped outright.

---

## 5. Debugging recipes

```bash
# See the Strada that perla generates for a .pl (great for "what node did this become"):
~/p/perla/perla --strada script.pl | less

# gdb a generated native binary:
~/p/perla/perla -o /tmp/x script.pl
PERLA_NO_STACK_GUARD=1 gdb /tmp/x        # env var disables perla's SA_ONSTACK handler
(gdb) break perla_sub_Pkg__name
(gdb) run
(gdb) bt

# Real top frame under valgrind (perla's handler otherwise hides it):
PERLA_NO_STACK_GUARD=1 valgrind --num-callers=25 /tmp/x

# Capture a runtime-eval'd .pm that fails to parse: rapid-copy during the run —
# PERLA_EVAL_KEEP does NOT keep parse-failed ones.
while :; do cp /tmp/perla_eval_*_*.pm /tmp/keep/ 2>/dev/null; done &
```

When perla reports `[parse error] ... near 'ARRAY': expected OP, got IDENT 'ARRAY'`,
an `ARRAY(0x...)` stringification leaked into generated source — almost always an AST
node or arrayref that got stringified where a value was expected (see §2a/§2d).

---

## 6. Discipline

- One fix → rebuild → **full suite 159/159** → diff against real perl → commit → push.
  Never batch unrelated fixes; never commit with the suite red.
- Anything that runs perla on **real Bizowie modules or e.pl** is CAGED to 2GB:
  `~/p/perla/safe_run.sh --mem 2G --timeout N -- <cmd>`. Kill the WHOLE tree when
  aborting. Trivial greps/tiny test compiles run uncaged.
- After ANY perla change, clear ALL stale per-module objects **with parens** (find
  precedence bug — `-name A -o -name B -delete` only deletes B):
  `find <libdirs> \( -name '*.pm.o' -o -name '*.pm.so' \) -delete`
```
