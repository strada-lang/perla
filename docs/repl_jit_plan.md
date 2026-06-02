# Plan: rework the Perla REPL to a persistent-host JIT (.so + dlopen + shared pad)

Status: DELIVERED as `perla --jit-repl` (persistent-process REPL). Phases 0–1
done; the eval-STRING pad path (Phase 2) is retained but superseded by the
persistent REPL, which solves what eval-STRING could not (whole-container
reassignment). The legacy re-run-preamble REPL (`perla` no args) is unchanged.

## `perla --jit-repl` (the delivered persistent REPL)

Each line is compiled to a tiny module `.pm.so` and its `mod_init` is run **in
the one live perla process** via `dlopen` — NOT wrapped in eval-STRING's value-
capture `do{}` block, which is exactly why whole-container reassignment works.
State persists through the shared host stash plus auto-prepended `our` re-
declarations (each line is its own module, so a var must be declared in it to be
visible; the REPL tracks declared vars and prepends `our $x; our @a; …`). A
leading `my` is promoted to `our` so top-level lexicals persist too.

Build: the perla compiler binary now also links the perla runtime
(`perla_stash.o`/`perla_dbi.o`/…), defines the program-global preamble (special
vars, `$a`/`$b`, `@ARGV`, want-list flag, sort/closure cell tables), and is built
`-rdynamic` (the strada driver detects the `dlopen` in `_jit_run_line`), so each
line `.so` resolves runtime+stash symbols against this process. `_run_jit_repl`
calls `perla_init` + the special-var init at startup. Normal `perla foo.pl`
compilation is unaffected (verified).

Verified persisting across lines: scalars, `my` (promoted), arrays incl.
`@a=(...)`, hashes incl. `%h=(...)`, subs (calling persisted vars), and open
filehandles — including the original `open(F); my @file=<F>; print` case. Full
suite 159/159.

Remaining polish: dot-commands (`.clear`, `.load`), error isolation per line,
multi-line heredocs, and eventually making `--jit-repl` the default REPL.

## (historical) Original plan — Phase 0 mechanism + eval-STRING pad path

## Phase 0 result (validated)

`experiments/repl_jit/` is a standalone C harness that proves the core loop with
zero codegen changes: a persistent host holds a `StradaValue*` pad; each "line"
is compiled to its own `.so` (`gcc -shared -fPIC -fuse-ld=lld`), `dlopen`'d, and
called; the `.so` reads/writes the host pad through host-exported symbols
(`-rdynamic` host + `RTLD_GLOBAL`). Run `experiments/repl_jit/build.sh`:

- State persisted across **4 separate `.so` loads** (one `.so` sets `x`, a
  different one reads `x` and sets `y`, etc.) — no re-running, no heuristic.
- Per line: **~55 ms** to compile the tiny `.so` + **~0.1 ms** to dlopen+call
  (vs ~9.5 s/line for the current full-relink REPL). The runtime lives in the
  host, so the `.so` links nothing — that's where the speed comes from.

Conclusion: the dlopen/persist plumbing is settled. The remaining hard part is
the Phase 2 codegen mode that binds `my`/`our` to the pad.

## Why

The current REPL (`_run_repl` / `_repl_compile_and_run` in `perla.strada`) fakes
cross-line state by **re-running an accumulated preamble** as a fresh native
executable on every line. Consequences:

- **Persistence is a keyword heuristic.** Only `my/our/sub/use/package/require/
  state` (and now read-mode `open`, commit `ed4607e`) get re-added to the
  preamble. Plain global assignment (`$g = …`), `push @a, …`, write-mode opens,
  object identity, tied state, etc. don't persist.
- **O(n²) work.** Line N recompiles + relinks all N prior lines.
- **Prior statements re-execute**, so observable statements (`print`/`warn`)
  can't be persisted — which is the whole reason the heuristic exists.

Strada already does it the right way (`lib/Strada/JIT.strada`): compile each
snippet to C → a **`.so`** (gcc/tcc) → **`dlopen`** → execute, with variables and
subs persisting across evals via a **shared state hash**. The host process never
exits, so filehandles, the heap, and all runtime state persist naturally.

This plan brings that model to Perla.

## Reuse: `eval STRING` / `require` already dlopen a `.pm.so`

The dlopen/persist machinery is not new. `perla_eval_string` (runtime/perla_stash.c
~13241) writes the eval body to a temp `.pm`, forks `perla -M` to compile it to
`/tmp/perla_eval_<pid>_<id>.pm.so`, then `dlopen`s it and `dlsym`+calls its
`mod_init` — in the running process. Runtime `require`/`use` do the same per
`.pm.so`. So Phase 1 should reuse this path, with two changes toward the target:

1. Compile **in-process** (perla is the compiler) instead of forking `perla -M`.
2. Add the **shared lexical pad** — which `eval STRING` *also* lacks. Its own
   source comment (perla_stash.c ~13196) notes the eval body "can't close over"
   the caller's `my` vars precisely because it's a separate `.pm.so`. Phase 2's
   pad fixes the REPL **and** `eval STRING` lexical closure in one move.

## Phase 1 findings (measured) — pivots the design toward eval-reuse

Tested the "persistent process calls `perla_eval_string` per line" model directly
(repeated `eval '...'` in one perla process, vs perl):

| State across lines        | perla eval-model | note                                  |
|---------------------------|------------------|---------------------------------------|
| open filehandle (`F`)     | **persists**     | in-process; `open` band-aid is moot   |
| named sub (`sub greet`)   | **persists**     | registers in the stash                 |
| package scalar (`our $x`) | **does NOT**     | eval body's `$x` not bound to `$main::x` (`x=` vs perl `42`) |

Implications:
- Phase 1 (process-persistence) largely falls out of reusing `perla_eval_string`
  in a persistent loop — filehandles/subs/`$@` come for free.
- But package scalars regress without the pad, so **Phase 2's pad must cover BOTH
  package vars and `my` lexicals**, not just lexicals. The same pad then fixes
  `eval STRING`'s package-var/lexical visibility too.
- Net: build the REPL on `perla_eval_string` + a shared pad; the marker/main()
  transform approach is dropped (modules have no init preamble to split).

## Phase 2 scalar var-pad: DONE (branch repl-jit-eval-var-pad)

The eval/REPL scalar var-pad now round-trips. Three coordinated changes on top
of step-2a (the `perla_scalar_lvalue` primitive + main-mode `our`-scalar macro):

1. `perla_eval_string` propagates `PERLA_REPL_PAD` to the forked `perla -M`
   compile, so eval bodies are compiled in pad mode (perla_stash.c ~13486).
2. Path B (expression-context scalar assignment, CodeGen ~9063) emits the
   `perla_glob_store` write-back for `our`/package scalars under pad mode, keyed
   on the declared package (`$cg{"pkg"}` = `main` during eval-body stmt gen) —
   Path A (statement context) already had this; eval bodies use Path B.
3. The `our`-decl codegen registers the scalar in `our_vars` under pad mode
   (CodeGen ~1999), because `collect_our_vars` doesn't descend into the eval
   wrapper's `my $rv = do { ... }` initializer, so Path B's gate would miss it.

Verified: `our $x=5; eval q{our $x;$x=9}; eval q{our $x;$x++}` → 10; cross-eval
set/++ → 42; string `.=` across evals; FQ `$main::x` read of an eval write; all
under `PERLA_REPL_PAD=1`. Pad OFF (default) ⇒ byte-identical ⇒ full suite
159/159. Valgrind: pad-on == pad-off (no added leak), 0 errors.

### Arrays / hashes (measured — partial; container-aware fix is the follow-up)

Tested arrays/hashes under the scalar-var-pad build:
- **In-place mutation already works**: `$a[i]=`, `$h{k}=`, `push`, and the same
  across multiple evals (e.g. `eval{$h{x}=1}; eval{$h{y}=2}` → both keys). This
  works because `our @a`/`our %h` adopt the shared stash container on entry and
  mutate it in place — the container identity is preserved, so all `.so`s see it.
- **Whole-container reassignment is the gap**: `@a=(...)` / `%h=(...)` *replace*
  the container, so after an eval reassigns, an outer/other-eval read sees the
  stale one. Single-eval whole-array assign happens to work (the eval mutates the
  adopted container); chained reassign-then-mutate and whole-hash assign do not.
- **The scalar read-macro does NOT generalize to containers.** Aliasing
  `v_a`/`v_h` to `(*perla_array_lvalue(...))` broke the *working* in-place cases:
  the `our`-decl adoption logic (`if(!v_a) v_a=new; v_a=slot; incref`) interacts
  badly with a slot-alias (the conditional-new + decref/incref churn corrupts the
  shared container). Reverted. The runtime `perla_array_lvalue`/`perla_hash_lvalue`
  primitives were prototyped and also reverted (unused without a working emit).

So the container fix is its own careful step: make whole-container reassignment
**clear+refill the adopted container in place** (matching how the working cases
behave) rather than replacing it, under pad mode — NOT a read-macro.

UPDATE — in-place clear+refill IMPLEMENTED (hashes), gated, suite 159/159:
- runtime `perla_hash_clear`/`perla_array_clear` (clear a non-tied container in
  place); whole-hash `%h=(...)` under pad+our refills the adopted container
  rather than replacing it (CodeGen ~16205); the mod_name-keyed Exporter
  `sync_block` now skips pad our-vars so it can't clobber the adopted container;
  our-decl registers scalar/array/hash in `our_vars` under pad.
- Works in MAIN mode (single program / REPL host's own code): `%h=(a,b)` → 2,
  chained `%h=(a); %h=(b)` → b.
- Element / in-place mutation (`$h{k}=`, `$a[i]=`, push) already persists across
  evals — the common REPL pattern — and still does.
- STILL BLOCKED across the eval `.so` boundary for whole-reassignment: the eval
  body's `our %h` adoption finds the main HASH slot empty and creates a fresh
  container (`v_h = strada_new_hash()`), so the in-place refill hits a container
  the outer doesn't share. Root cause = a main-mode-vs-module-mode `our %h/@a`
  adoption asymmetry (element mutation populates+shares the slot; whole-reassign's
  adoption path doesn't). Fixing that adoption asymmetry is the remaining item;
  arrays are analogous (same in-place mechanism applies once adoption is fixed).

REMAINING (follow-ups in this effort): arrays/hashes whole-reassignment
(in-place refill), `my` lexicals via the `__perla_lex_`/`__caps` mechanism, and
the persistent eval-loop REPL that turns pad-on by default and retires the
preamble re-run.

## Phase 2 design (characterized, measured) — the "pad" is the existing registry

Key finding: **no new pad structure is needed.** perla's `perla_scalar_get/set(pkg,
name)` registry (perla_stash.c ~2716) is already a process-global store that
resolves across `.so` via host symbols. Measured across an eval `.pm.so`:

| Access form                | read | write | why                                              |
|----------------------------|------|-------|--------------------------------------------------|
| `$main::x` (fully-qualified)| ✓    | ✓     | lowered to perla_scalar_get/set — fully shared   |
| `our $x` then `$x`         | ✓    | ✗     | reads registry, but writes hit the local `v_x` mirror only |
| bare `$x` (no decl)        | ✗    | ✗     | lowered to a fresh local in the `.so`            |

So the registry IS the shared pad; the gap is **write-through** for top-level
`our`/package scalars (FQ already works end to end). perla also already stashes
lexicals in the registry under mangled keys — `__perla_lex_<name>` (format/`write`
capture, CodeGen ~4389/4418) and the `__caps` hash
(`perla_eval_string_with_lexicals`) — i.e. the pad pattern exists for `my` too.

### Step-2 progress (in flight)

DONE: the pad mechanism + gating.
- Runtime: `perla_scalar_lvalue(pkg,name)` returns a true lvalue into the shared
  stash slot (perla_stash.c).
- Codegen: `pad_mode` flag (env `PERLA_REPL_PAD`, default OFF). When on, a
  **file-scope** `our`/package scalar is emitted as
  `#define v_x (*perla_scalar_lvalue("pkg","x"))`, so every existing read/write
  transparently hits the shared registry — no per-write-site changes.
- Verified: single program writes through (`our $x=5; $x=9` → 9 via the slot).
- Safety: pad OFF ⇒ byte-identical codegen ⇒ full suite 159/159 (confirmed).

NEXT (remaining step 2/3/4):
- Sub-step 1 investigation (done): the eval round-trip blocker is now precise.
  `PERLA_REPL_PAD` DOES propagate to the eval's `perla -M` child (env confirmed),
  and `our` inside a sub IS collected into our_vars. The real obstacles:
  1. **Module mode emits each `our` var at multiple decl sites.** The main-mode
     macro is at one site; module mode (CodeGen ~1274 + a second `static
     StradaValue *v_X` emit ~90 lines into the generated C) emits it twice, so
     gating only one site yields a `#define v_X` + `static ... v_X` collision.
     ALL module our-decl sites + the per-entry adoption block
     (`perla_glob_get_or_create(...); v_X = slot...`) must be gated together.
  2. **Package resolution.** An eval body wraps as `package main; sub
     __perla_eval_body_N {...}` but the module's `$cg{"pkg"}` is the synthetic
     `perla_eval_N` name. The lvalue must key on the var's DECLARED package
     (`main` here), not the compilation-unit name — the existing glob-adoption
     code already uses `"main"`, so the info is available at statement level.
  3. **Write-back asymmetry.** Main-mode our-assign emits a `perla_glob_store`
     write-back after `v_x = ...`; module/eval-mode assign does NOT — so even
     without the macro, an eval's `our $x` write never reaches the slot. The
     macro fixes this for free (v_x IS the slot) once 1+2 are resolved.
  So the next pass: gate ALL module our-decl/adoption sites consistently, keyed
  on the declared package. Reverted the partial module-site edit to keep the
  pad-on path conflict-free; main-mode step-2a stands (suite 159/159).
- DEEPER MAP (next-pass investigation): the module/eval `our`-var path spans
  4–5 intertwined mechanisms, not 2 — coordinating them is the actual work:
  (a) our-decl emit, main ~221 and module ~1274 (+ a second `static v_X` emit);
  (b) `our`-init adoption blocks ~1871–2058 (keyed on `$cg{"pkg"}`);
  (c) the Exporter-import `sync_block` ~1601/1606 — keyed on the synthetic
      `$mod_name`, NOT the declared package (so eval `main::x` reads the wrong
      stash); (d) the assignment write-back (emitted main-mode, missing
      module-mode); (e) package resolution (eval body = `package main`).
  A correct pass rekeys (b)+(c) on the declared package and adds (d) in module
  mode, all under pad_mode. This is dedicated focused work — too intertwined to
  land safely as an incremental edit without risking the suite.
- DEDICATED-PASS RESULT (measured): the asymmetry is finer than "(d) main vs
  module". There are MULTIPLE scalar-assignment codegen paths:
  - Path A (~8895-8922, statement context, `__old_sv`/`v_x = __new_sv`) emits the
    glob_store write-back UNCONDITIONALLY (keyed on `$cg{"pkg"}`). A plain
    `sub body { our $x; $x=9 }` uses Path A — so it DOES write back.
  - Path B (~9038-9063, expression context, `__asn_old`/`__asn_new`) does NOT.
    The eval body uses Path B because the eval wrapper captures the last
    expression value (statement-expr / do-block), forcing expression context.
  Adding the write-back to Path B (gated, keyed on `$cg{"pkg"}`) was tried and is
  correct-by-construction, BUT it still didn't fire for the real eval: the
  eval-body wrapper's special collection (Collect.strada ~161, `__perla_eval_body_`
  / `is_eb`) does not put the body's `our $x` into `$cg{"our_vars"}` the way a
  normal sub does, so an our_vars-gated condition misses it. So the full fix is a
  THIRD mechanism: make eval-body collection register its `our` vars (or gate the
  Path B write-back on the register_our_local set instead of our_vars). Net: the
  eval var-pad spans (1) multiple assignment paths, (2) eval-body var collection,
  (3) package keying — a genuine multi-day codegen change, not a session edit.
  Reverted all speculative edits; verified main-mode step-2a + suite 159/159.
- Then: plumb pad-on for the REPL host build; arrays/hashes; `my` lexicals.

### Concrete Phase 2 steps (suite-critical codegen — do carefully, well-tested)

1. **REPL/eval codegen mode flag.** A `cg` flag set when lowering a REPL line (or
   eval body) so the changes below don't touch normal `perla foo.pl` output.
2. **Top-level scalars → registry, read+write.** In that mode, lower top-level
   `$x`/`our $x` reads to `perla_scalar_get(pkg,"x")` and writes to
   `perla_scalar_set(pkg,"x",...)` (write-through) — i.e. give every top-level
   package scalar the `$main::x` treatment that already works. Closes the `our`
   write-through gap (and fixes `eval STRING` package-var visibility).
3. **Arrays/hashes.** Same routing via the array/hash registry equivalents
   (`perla_array_*`/`perla_hash_*` — confirm/extend the runtime API).
4. **`my` lexicals at REPL top level → pad.** Reuse the `__perla_lex_<name>` /
   `__caps` mechanism: bind from the pad on entry, write back on exit. Promotes
   line-local `my` to session-persistent without making them globals.
5. **Persistent eval-loop REPL.** Replace `_run_repl`'s compile-a-whole-exe with
   a loop that calls `perla_eval_string` (or a pad-aware variant) per line in the
   one persistent process. Filehandles/subs already persist (Phase 1 finding);
   steps 2–4 add var persistence.
6. **Retire** the preamble re-run + keyword heuristic (incl. the `open`
   band-aid). Verify against the full suite + a REPL persistence test matrix
   (scalar/array/hash/sub/filehandle across lines; redefinition; `local`/`$@`).

Risk: steps 2–4 touch the most delicate codegen (variable lowering); gate behind
the mode flag and test each against the 159-test suite before moving on.

## Target architecture

```
┌────────────────────────── persistent perla --repl host process ──────────────────────────┐
│  perla runtime linked in (strada_runtime + perla_stash), exported via -rdynamic           │
│  perla_repl_pad   : StradaHash*  name -> StradaValue*   (lexical/our vars persist here)    │
│  perla stash      : existing package/sub/method registry (subs persist here)              │
│  open filehandles, heap, $@, special vars: live in-process, persist for free              │
│                                                                                            │
│   per line:  Perl line ──parse/codegen──▶ tiny .c ──gcc -shared -fPIC -fuse-ld=lld──▶ .so  │
│              ──dlopen──▶ dlsym("perla_repl_eval_N") ──call──▶ reads/writes pad + stash     │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

Key inversion vs. today: **the runtime stays resident in the host; only the
line's own code is compiled per step.** The `.so` references host symbols, so it
does NOT link the ~4 MB `perla_runtime.a` each line — the link becomes tiny and
fast (this is also why latency stops being a problem without tcc).

## The hard part: a persistent "pad" for variables and subs

perla currently lowers `$foo` to a C local `v_foo`, which evaporates at program
exit. The rework needs a **REPL codegen mode** where REPL-top-level bindings live
in a persistent structure the next `.so` can see:

- **Lexicals / `our` at REPL top level → `perla_repl_pad`.** On `.so` entry, bind
  each referenced name from the pad (`v_foo = pad_get("foo")`); on exit, write
  back (`pad_set("foo", v_foo)`). `our`/package vars can route through the
  existing `perla_global_*` registry, which already persists process-wide.
- **Subs / packages → the existing stash.** A `sub` compiled into one line's
  `.so` registers its function pointer by name in `perla_stash`, so later lines
  resolve it through normal dispatch. Redefinition = load the new `.so`, update
  the pointer.
- **Everything else is free.** Because each line runs exactly once in the live
  process, `print`/`warn`/`push`/`open`/sockets/`$@`/`local` all just work and
  persist with no heuristic.

## Symbol/ABI contract

- Host is built (or relinked) with `-rdynamic` so each `.so` resolves `strada_*`
  / `perla_*` runtime symbols and `perla_repl_pad` against the host.
- Each line's `.so` exports one entry: `void perla_repl_eval_N(void)` (or returns
  a `StradaValue*` for the value of the last expression, to echo it).
- `.so`s are kept loaded (never `dlclose`) so their subs stay callable; handles
  are tracked for teardown at REPL exit. (Long-session `.so` accumulation is
  acceptable for a REPL; optionally dlclose superseded redefinitions.)

## Compiler backend

Default **gcc** (honor the standing "no tcc" preference). The per-line `.so` is
tiny (only the line's code; runtime is in the host), so `gcc -shared -fPIC
-O0 -fuse-ld=lld` links in well under a second — reuse `_fast_link_flag()`.
tcc remains an opt-in fast path, not the default.

## Crash / error isolation

A native `.so` that segfaults takes the host with it (same caveat as strada's
JIT). Wrap each entry call in perla's existing eval/`longjmp` guard so `die`
unwinds cleanly; rely on the existing signal handler for hard faults. Full
sandboxing is out of scope.

## Phasing

0. **ABI design** — pad layout, entry-symbol convention, sub-registration hook,
   how the host exports symbols to `.so`s. Write a tiny C harness proving
   host-process ↔ dlopen'd-`.so` shared-pad read/write before touching codegen.
1. **Persistent host, stateless lines** — REPL stays resident; per-line `.c` →
   `.so` → dlopen → call. Expressions and `print`/`warn` work; no shared vars
   yet. Proves the loop + latency.
2. **Variable pad** — REPL-mode codegen binds/writes-back `my`/`our` top-level
   vars through `perla_repl_pad` (+ `perla_global_*`). Cross-line vars persist.
3. **Subs / packages / `use`** — register subs in the stash from each `.so`;
   handle redefinition and imports.
4. **Retire the old model** — delete the preamble re-run + the
   `my/our/.../open` keyword heuristic (this file's `ed4607e` band-aid included).
5. **Edge cases** — closures capturing pad vars, `tie`, filehandles (now free),
   `local`, `$@`, value-echo of the last expression, multi-line input buffering.

## Alternatives considered

- **Bytecode VM (à la `strada-interp`).** Cleanest latency + crash safety + true
  persistence, but Perla has no Perl bytecode VM; building one is far larger than
  reusing the existing C codegen. The `.so`/dlopen JIT is the pragmatic path.
- **Delegate perla's REPL to `strada-jit`.** Tempting, but the JIT must speak
  Perl semantics (the stash, special vars, `@_`, etc.), so a perla-specific host
  modeled on `Strada::JIT` is the right shape rather than literal delegation.

## Risks / open questions

- REPL-mode codegen is invasive; must be gated by a flag so normal `perla foo.pl`
  compiles are byte-for-byte unaffected.
- Pad typing: values are `StradaValue*`; arrays/hashes persist by their container
  pointer — confirm refcount ownership across `.so` boundaries (the pad holds the
  owning ref; `.so` entry borrows).
- `.so` accumulation over very long sessions (memory) — track handles, optionally
  dlclose superseded ones.
- Whether to reuse perla's existing runtime-`eval`/`require` machinery (which
  today shells out to a child `perla`) by pointing it at the same in-process JIT.
