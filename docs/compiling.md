# Compiling with Perla

## Two modes

- `./perla script.pl` — compile *and* run. Produces `./script` as a
  side effect, runs it, cleans up (unless `--keep` is set).
- `./perla -o prog script.pl` — compile to executable, leave it in
  place. Doesn't run.
- `./perla -c -o out.c script.pl` — generate C only, no compile.
- `./perla -e 'code'` — one-liner.
- `./perla -M Module.pm` or `./perla -M dir/` — precompile a module
  or a whole tree to `.pm.o` / `.pm.so`.

## Full flag reference

| Flag | Effect |
|---|---|
| `-o FILE` | Output path (executable with normal mode, C file with `-c`) |
| `-c` | Generate C only; don't invoke cc |
| `-e 'CODE'` | Execute an inline one-liner |
| `-M FILE.pm` | Precompile module: emit `FILE.pm.o` (+`.pm.so` with `PERLA_BUILD_PM_SO=1`) |
| `-M DIR/` | Recursively precompile every `.pm` under `DIR/` (idempotent) |
| `-I PATH` | Add to compile-time `@INC` |
| `--cc BIN` | Use a specific C compiler (default `gcc`; `tcc` option for faster dev iteration) |
| `--debug` | Verbose tracing: lib-path search, cache hits, auto-build events, full cc command |
| `--keep` / `--keep-c` | Don't delete the generated `.c` after compile |
| `-O0 -O1 -O2 -O3 -Os -Ofast` | gcc optimization level. Default `-O0`. `-O2+` also passes `-flto`; `-O3/-Ofast` also passes `-march=native`. |
| `--precompile-deps` | During normal compile, auto-build `.pm.o`+`.pm.so` for every module encountered |
| `--shared` | Prefer `.pm.so` (dlopen at runtime) over `.pm.o` (static link) when both exist |
| `--force-rebuild` | `perla -M` re-builds every module even if artifacts exist |
| `--vm` | Run via Strada codegen interpreter path (no cc) |
| `--strada` | Emit Strada source instead of C |
| `-v, --version`, `-h, --help` | Obvious |

## Optimization levels

Matches strada's naming. Default is `-O0` for fast dev iteration.

| Flag | Added gcc args | Use case |
|---|---|---|
| (default) | `-O0 -w` | Fast compile, slow binary. Dev iteration. |
| `-O0` | `-O0 -w` | Explicit no-opt |
| `-O1` | `-O1 -w` | Basic opts |
| `-O2` | `-O2 -w -flto` | Standard release |
| `-O3` | `-O3 -w -flto -march=native` | Max perf, CPU-specific |
| `-Os` | `-Os -w -flto` | Size-optimized |
| `-Ofast` | `-Ofast -w -flto -march=native` | Aggressive (may violate strict IEEE) |

Measured on a ~20MB generated C file: `-O2` took 1:48 at the gcc
step alone; `-O0` took 16s. Roughly 6.5× faster link in exchange for
a slower runtime — fine for iterating on Perl source, not what
you'd ship.

## The two search paths

Perla has two distinct lookup paths for `use Module::Name`:

### Compile-time (source parsing / inlining)

Built by `_build_lib_paths` in `perla/perla.strada`:

1. Directory of the input file
2. Current directory (`.`)
3. `$PERLA5LIB` env var (colon-separated)
4. `$PERL5LIB` (Perl compat)
5. `$HOME/perla/lib` (if it exists)
6. `-I path` flags (prepended — highest priority)
7. `use lib "..."` statements encountered during parse

**Not on this path**: `/opt/bzperl/lib/...` or any other CPAN tree.
Putting large library trees on the compile-time search would balloon
source parsing; it's intentionally excluded.

### Runtime (`require` / dlopen)

Baked into the executable at compile time. Plus at startup:

1. `PERLA_LIB` env (colon-separated)
2. `lib_path` from `~/.perla/perla.conf` or `/etc/perla.conf`
3. Archlib auto-expansion: each path added is also probed for a
   `x86_64-linux/` or `x86_64-linux-gnu-thread-multi/` subdir and
   those are added too (for XS stubs)

### In practice

- For an app, `use lib '/opt/bzperl/...'` in the script puts the CPAN
  tree on the *compile-time* path (so `use SomeModule` inlines).
- For *runtime* `require` of precompiled `.pm.o` / `.pm.so`, Perla
  writes a magic comment into the generated C listing the required
  `.o` files, then the gcc link pulls them in.

`--debug` prints both paths and every search attempt. See below.

## `--debug` output

Four categories of trace, prefixed for easy grep:

```
[perla] startup / config lines
[perla]   per-module resolution events
[cc]      the full cc command being invoked
[require] runtime require attempts (inside the compiled binary)
```

Example run:

```
[perla] debug mode enabled
[perla] cc: gcc
[perla] compile-time lib paths (5):
[perla]   [0] /tmp
[perla]   [1] .
[perla]   [2] /opt/bzperl/lib/site_perl/5.42.0
[perla]   [3] /opt/bzperl/lib/5.42.0
[perla]   [4] $HOME/perla/lib
[perla] use Carp
[perla]   Carp: cache HIT /opt/bzperl/lib/5.42.0/Carp.pm [.pm.o (static)]
[perla] use File::Spec
[perla]   File::Spec: cache MISS /opt/bzperl/lib/5.42.0/File/Spec.pm
                      — auto-building via perla -M
[perla]     spawn: PERLA_MODULE_NAME= PERLA_BUILDING_LIST=...
                   /path/perla -M /opt/bzperl/.../File/Spec.pm 2>&1
[perla]   File::Spec: auto-build OK
[perla] use Abe::DB::User -> already loaded (skip)
[cc] gcc -O0 -w -o hello hello.c /opt/bzperl/.../Carp.pm.o ... 2>&1
[cc] done in 16.03s (ok)
```

Dump event vocabulary:

| Event | Meaning |
|---|---|
| `use Foo::Bar` | Fresh load starting |
| `use X -> already loaded (skip)` | Name-based dedup hit |
| `X: resolved to already-loaded path ...` | Path-based dedup hit (different name, same file) |
| `X: cache HIT /path [.pm.o (static)]` | Found a precompiled artifact; will link statically |
| `X: cache HIT /path [.pm.so (shared)]` | Same but uses dlopen under `--shared` |
| `X: cache MISS /path — auto-building via perla -M` | Narrow heuristic fired, spawning child compile |
| `X: cache MISS /path (no auto-build — narrow heuristic skipped)` | Source won't be inlined; runtime require will try |
| `X: source /path (non-tree, will inline)` | Project-local module, source gets inlined |
| `X: XS module detected — skipping` | Found an `auto/.../*.so` alongside the `.pm`. Not compiled in-tree — loaded at runtime via XSLoader instead. See [`cpan.md`](cpan.md). |
| `X: parsing source /path` | About to tokenize + parse |
| `X: emit precompiled (.pm.o static) /path` | CodeGen chose static link for this module |
| `X: emit precompiled (.pm.so dlopen) /path` | CodeGen chose dlopen |
| `X: NOT FOUND at compile time` | Nothing resolved; runtime require will retry |
| `probing perl @INC for fallback` | First @INC cache miss — probing `perl -V` |
| `build-cycle guard tripped` | `PERLA_BUILDING_LIST` caught a `use`-cycle; skipping recursive build |

## The precompile cache

`perla -M` writes two artifacts next to the source:

- `Foo/Bar.pm.o` — static-link object
- `Foo/Bar.pm.deps` — transitive dependency list (other `.pm.o`
  paths pulled in via its own `use` statements)

And optionally with `PERLA_BUILD_PM_SO=1` or `--shared`:

- `Foo/Bar.pm.so` — dlopen-able shared library

A subsequent `./perla script.pl` that does `use Foo::Bar` picks up
`Bar.pm.o` from the cache (cache HIT in `--debug`) and skips re-parsing
the source. This dramatically speeds up iteration on anything that
doesn't touch the module.

### Directory mode

```bash
./perla -M lib/                  # walk lib/ recursively, build every .pm
./perla --force-rebuild -M lib/  # rebuild even if .pm.o already exists
```

Idempotent — already-built modules are skipped. A typical app
`Makefile` wraps this with `make precompile` / `make precompile-force` /
`make precompile-clean` targets.

### Narrow auto-build (default)

During a normal compile, Perla *doesn't* auto-build every `.pm` it
encounters — doing so would turn every compile into a multi-minute
warm-up the first time. Instead it uses a **narrow heuristic**:
auto-build a `.pm.o` only when the source looks like it defines an
`import` sub that installs `@ISA` (the kind of `use base` /
`use parent` pattern that silently breaks when skipped). Matches `sub
import`, `*{$M.import}`, `our @EXPORT`, etc.

To precompile every dep regardless, pass `--precompile-deps`. Or run
`perla -M DIR/` once up front.

### `--shared` mode

Instead of statically linking `.pm.o`'s into the final exe, emit a
`dlopen` at program startup. Smaller main binary; uses `.pm.so`
siblings of `.pm.o`. Requires `PERLA_BUILD_PM_SO=1` when building
modules (or set by `--shared`).

## `--keep` / inspecting the generated C

When things compile but behave weirdly, `--keep` leaves the
intermediate `.c` for inspection:

```bash
./perla --keep -o prog prog.pl
ls prog.c                  # left behind
```

Under `--debug`, the path is also printed: `[perla] kept C file:
/path/prog.c`.

The `.c` contains every emitted sub body, the init sequence, and
magic comments like `/* PERLA_LINK_OBJECTS: ... */` listing the
`.pm.o` files the driver collected for the gcc link step. If you
want to reproduce the gcc step by hand, copy the `[cc]` debug line
verbatim.

## Environment variables Perla reads

| Var | Effect |
|---|---|
| `PERL5LIB` / `PERLA5LIB` | Colon-separated compile-time search paths |
| `PERLA_LIB` | Runtime-require search paths (rare; usually baked in) |
| `PERLA_PERL` | Path to a real `perl` binary. Used for `@INC` fallback probing, to inline XS-adjacent paths, and as a compile-time helper. |
| `PERLA_PRECOMPILE_DEPS=1` | Same as `--precompile-deps` |
| `PERLA_SHARED=1` | Same as `--shared` |
| `PERLA_FORCE_REBUILD=1` | Same as `--force-rebuild` |
| `PERLA_NO_AUTO_BUILD=1` | Disable narrow auto-build heuristic |
| `PERLA_BUILD_PM_SO=1` | `perla -M` also builds `.pm.so`, not just `.pm.o` |
| `PERLA_DEBUG=1` | Same as `--debug` |
| `PERLA_DBI_DEBUG=1` | Verbose DBI method traces |
| `PERLA_METHOD_DEBUG=1` | Verbose method dispatch traces |
| `PERLA_INIT_DEBUG=1` | Trace `init()` method resolution |
| `PERLA_CC` | Override cc (same as `--cc`) |
| `PERLA_MODULE_NAME` | (Internal) override for `-M` when invoked by the auto-builder |
| `PERLA_BUILDING_LIST` | (Internal) recursion guard — colon-sep list of in-progress `perla -M` targets |

## Common failure modes

### `sh: 1: foo: not found` after a seemingly-successful compile

Happens when `./perla foo.pl` compiles but the compiled binary isn't
on PATH. Fixed in a recent commit — Perla now prefixes `./` when
the exe path has no slash.

### `redefinition of 'perla_sub_Foo_bar'` during `perla -M`

Either (a) the Perl source literally defines the same sub twice
(merge-conflict leftovers — Perl would warn-and-overwrite at runtime;
Perla matches that by emitting only the last definition now), or
(b) the target `.pm` is being re-parsed via a dependency cycle.
Perla's module-level cache is name-keyed *and* path-keyed, so both
cases should be caught. If you see this today, grep for duplicate
`sub NAME` in the source.

### `undefined reference to perla_mod_init_Xxx` at link time

A precompiled `.pm.o` was built with the wrong module name — `.pm.o`
symbol doesn't match the `perla_mod_init_Xxx()` call the main `.c`
emits. Happens when `perla -M` is given a path it can't map back to
the correct `Foo::Bar` package name. `perla -M /abs/path/to/lib/Foo/Bar.pm`
and `perla -M lib/Foo/Bar.pm` (relative) both work now. To be safe,
set `PERLA_MODULE_NAME=Foo::Bar` explicitly when invoking `perla -M`
against a weird path.

### `Can't locate object method X via package "REF(0x0x...)"`

Means a variable holding a blessed ref was stringified (via
`strada_to_str`) and the stringified form was used as a class name.
`perla_bless($self, $class)` now uses `perla_class_name()` which
unwraps blessed `$class` properly; if you still see this, you've got
a manual `strada_to_str` somewhere in your code that needs swapping to
`perla_class_name`.

### `Can't locate package X in @INC` at runtime

Module name-to-path translation failed. Check `--debug` — the
`[require] searching ...` lines show every path attempted. Usually
means the module source isn't on the runtime path or the `.pm.o`
cache is stale.
