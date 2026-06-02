# Installing CPAN modules

Perla ships three scripts. Day-to-day you mostly touch one:

| Script | Path | Purpose |
|---|---|---|
| **`perla-cpan`** | `perla/tools/perla-cpan` | End-user installer. Fetches from CPAN by name, resolves deps, installs `.pm` + XS `.so` into a prefix. |
| **`perla-xs-build`** | `perla/tools/perla-xs-build` | Low-level XS compiler. Turns `.xs` → `.o` / `.so` against Perla's `perl.h` shim. |
| **`perla`** | `perla/perla` | The compiler/runtime. `.pl` → native executable, or interprets via `--vm`. |

> There's also an older `perla/perla-cpan` binary built from
> `perla/perla-cpan.strada`. Ignore it — the bash tool in
> `perla/tools/perla-cpan` is the current one and what this doc
> describes.

## Quick start

```bash
# One-time setup
export PERLA_LIB=$HOME/.perla/local/lib/perla5
export PERLA5LIB=$PERLA_LIB

# Install what your program needs (deps auto-resolved)
perla/tools/perla-cpan Try::Tiny Path::Tiny JSON::MaybeXS

# Compile + run
perla/perla myprog.pl
```

## `perla-cpan` — install CPAN modules

```
perla-cpan [options] SOURCE

SOURCE:
  Module::Name                   fetched from MetaCPAN (deps auto-resolved)
  /path/to/Dist-1.0/             pre-unpacked directory (no deps by default)
  /path/to/Dist-1.0.tar.gz       local tarball (.tar.gz / .tgz / .tar.bz2 / .tar)
```

### Common invocations

```bash
# By name — fetches from CPAN with transitive runtime deps
perla-cpan Try::Tiny
perla-cpan --prefix=/opt/perla-libs Path::Tiny

# Local source (no deps by default — add --deps to recurse)
perla-cpan ~/build/My-Dist-1.0/
perla-cpan --deps ~/dl/Foo-Bar.tar.gz

# Skip the transitive-dep recursion
perla-cpan --no-deps Heavy::Module

# Pure-Perl only (skip XS compilation entirely)
perla-cpan --no-xs Foo::Bar

# Also build .pm.o / .pm.so sidecars (slower, enables lazy loading)
perla-cpan --precompile Foo::Bar

# Force CPAN fetch even if the name looks ambiguous
perla-cpan --from-cpan some_name

# Dry run — show what would happen, install nothing
perla-cpan --dry-run Foo::Bar
```

### All flags

| Flag | Default | Meaning |
|---|---|---|
| `--prefix DIR` | `$HOME/.perla/local` | Install root |
| `--lib-subdir DIR` | `lib/perla5` | Subdir under prefix for `.pm` files |
| `--precompile` | off | Run `perla -M` on each installed `.pm` to build `.pm.o` / `.pm.so` |
| `--no-xs` | (XS on) | Skip XS compilation entirely |
| `--xs-static` | (XS shared) | Build `.o` for manual static linking instead of `.so` |
| `--with-tests` | off | Also install the `t/` directory |
| `--from-cpan` | (auto) | Force MetaCPAN fetch regardless of source format |
| `--deps` | (on for CPAN, off for local) | Install transitive runtime deps from META.json |
| `--no-deps` | | Skip transitive deps even for CPAN fetch |
| `--manifest FILE` | `$PREFIX/var/perla/cpan/<dist>.manifest` | Where to write the manifest |
| `-n`, `--dry-run` | off | Show what would happen, install nothing |
| `-v`, `--verbose` | off | Print each command as it runs |

### Install layout

```
$PREFIX/
├── lib/perla5/                     ← point PERLA_LIB here
│   ├── Try/Tiny.pm
│   ├── Path/Tiny.pm
│   └── auto/
│       └── Foo/Bar/Bar.so          ← XS: dlopen'd at runtime by XSLoader
└── var/perla/cpan/
    ├── Try-Tiny.manifest           ← list of files installed
    └── Path-Tiny.manifest
```

### Dependency resolution

`perla-cpan` reads `META.json` → `prereqs.runtime.requires` and
recursively installs each non-core dependency. Core/dual-life modules
(`Exporter`, `Carp`, `strict`, `JSON::PP`, `File::*`, `Scalar::Util`,
…) are hardcoded to skip — Perla already stubs or builds those in.

The recursion is cycle-safe (visited set passed via
`$PERLA_CPAN_VISITED`) and already-installed modules at the prefix
are skipped (cheap re-runs).

If a dep fails, `perla-cpan` logs a warning and continues — a single
broken dep doesn't abort the whole install.

## `perla-xs-build` — compile one XS module

You rarely call this directly (perla-cpan does, for every `.xs` in a
CPAN distribution). Useful when you're authoring your own XS or
debugging why a specific module fails to build.

```bash
perla-xs-build MyMath.xs                 # → MyMath.o
perla-xs-build --shared MyMath.xs        # → MyMath.so (dlopen-able)
perla-xs-build --module Foo::Bar foo.xs  # override module name
perla-xs-build -v --keep-c MyMath.xs     # verbose + keep intermediate .c
perla-xs-build -O3 -I/opt/local/include foo.xs
```

`--shared` is what `perla-cpan` passes by default, producing the
`auto/<path>/<base>.so` that Perla's runtime `XSLoader::load` hook
dlopens.

## `perla` — compile / run Perl

```bash
perla prog.pl               # compile + run
perla -o prog prog.pl       # compile to named executable
perla -c prog.pl            # keep generated .c
perla --vm prog.pl          # interpreter (no compile — see Limits)
perla --debug prog.pl       # verbose compile trace: [xsloader], [require], [cc]
perla -M lib/Foo.pm         # precompile one module
perla -M lib/               # precompile every .pm under a directory
```

See [`compiling.md`](compiling.md) for the full flag matrix.

## Environment variables

| Variable | When | What |
|---|---|---|
| `PERLA_LIB` | runtime | Where compiled binaries look for `.pm` and `auto/*.so` |
| `PERLA5LIB` | compile time | Where `perla` looks for `.pm` during compilation (colon-separated) |
| `PERL5LIB` | compile time | Perl-compat alias for `PERLA5LIB` |
| `PERLA_PREFIX` | `perla-cpan` | Default install prefix (overridden by `--prefix`) |
| `PERLA_DEBUG=1` | runtime | Emit `[xsloader]`, `[require]`, `[xs-build]` traces to stderr |
| `METACPAN_BASE` | `perla-cpan` | Override MetaCPAN API base (default: `https://fastapi.metacpan.org/v1`) |
| `STRADA_DIR` | any | Strada tree root (auto-detected from script location otherwise) |

### `PERLA_LIB` vs `PERLA5LIB`

This is the most common point of confusion.

- **`PERLA5LIB`** is read at **compile time**. `use Foo::Bar` in your
  Perl source triggers a compile-time search of `PERLA5LIB` paths for
  `Foo/Bar.pm`. Without it, the compile fails with
  `Can't locate Foo/Bar.pm`.
- **`PERLA_LIB`** is read at **runtime**. The compiled binary uses it
  to find `.pm.so` precompiled sidecars and `auto/*.so` XS libraries.

Set **both** to the same directory for the typical case:

```bash
export PERLA_LIB=$HOME/.perla/local/lib/perla5
export PERLA5LIB=$PERLA_LIB
```

## End-to-end example

Write your program:

```perl
# myapp.pl
use strict;
use Try::Tiny qw(try catch);

my $result = try {
    die "oops\n";
    "unreachable";
} catch {
    "caught: $_";
};
print $result;
```

Install the dep and run:

```bash
# Install Try::Tiny into a private prefix
$ perla-cpan --prefix=./vendor Try::Tiny
[cpan] fetching Try::Tiny from CPAN
[cpan] Try-Tiny → ./vendor
[cpan]   .pm installed: 1
[cpan]   deps: 0 installed, 6 skipped, 0 failed

# Point at the prefix and compile+run
$ PERLA_LIB=./vendor/lib/perla5 PERLA5LIB=./vendor/lib/perla5 perla myapp.pl
caught: oops
```

## XS modules

XS modules install end-to-end. A typical Perl XS stub:

```perl
package MyMath;
use Exporter 'import';
our @EXPORT_OK = qw(add multiply);
use XSLoader;
XSLoader::load('MyMath', $VERSION);
1;
```

Flow at install time:
1. `perla-cpan` copies `lib/MyMath.pm` to `$PREFIX/lib/perla5/MyMath.pm`
2. Finds `MyMath.xs`, runs `perla-xs-build --shared` → `$PREFIX/lib/perla5/auto/MyMath/MyMath.so`

Flow at runtime (when your program does `use MyMath qw(add)`):
1. Compiled `MyMath.pm` runs its top-level code
2. Top-level code calls `XSLoader::load('MyMath')` → our runtime hook
3. Runtime hook finds `auto/MyMath/MyMath.so` on `PERLA_LIB`, dlopens it
4. Calls `boot_MyMath`, which registers XS subs via `newXS_deffile`
5. `use ... qw(add)` → Exporter sees `@EXPORT_OK`, aliases `add` into caller
6. `add(3, 4)` → stash lookup → XSUB dispatch → native C code → `7`

## Gotchas

- **Set both `PERLA_LIB` and `PERLA5LIB`.** Compile time and runtime
  read different variables. Easy to set one and wonder why `use` works
  but calls fail (or vice versa).
- **`perla --vm` doesn't support XS.** The VM path doesn't route
  through `perla_init` (the C runtime init that wires XSLoader). Use
  compiled mode for anything with XS.
- **XS must be `.so`, not `.o`.** XSLoader needs something dlopen'able.
  `perla-cpan` defaults to `.so`; only use `--xs-static` if you're
  manually linking.
- **Dual-life core modules resolve to `dist=perl`.** `perla-cpan`
  refuses those (would download ~4000 files from Perl core). The
  core/skip-list already covers the common ones (`JSON::PP`,
  `File::Spec`, etc.); if a new one surfaces, add it to `is_core_module()`
  in `perla/tools/perla-cpan`.
- **Complex CPAN modules may surface compat gaps** in
  `runtime/perla_perl_compat.h` (missing Perl API macros). When
  an XS module fails to compile, `perla-xs-build` prints the undefined
  symbols; each is typically a one-line addition to the compat header.
- **`Makefile.PL` isn't executed.** `perla-cpan` reads `lib/` directly.
  Distributions with configure-time probing or code-generation need to
  be pre-built (run `perl Makefile.PL && make` first, then
  `perla-cpan` the resulting tree).
- **No version constraints.** Always grabs the latest release on
  CPAN. No `>=1.0, <2.0` satisfaction.
- **Don't confuse with the old `perla-cpan`.** There's a compiled
  binary at `perla/perla-cpan` built from `perla-cpan.strada`. It's
  older, has different flags, and depends on MetaCPAN calls that
  shell through python inline. Use `perla/tools/perla-cpan` instead.

## Where to go when things break

- **`use Foo` fails at compile time**: Missing from `PERLA5LIB`. Check
  `$PREFIX/lib/perla5/Foo.pm` exists; set `PERLA5LIB=$PREFIX/lib/perla5`.
- **`Can't locate method` at runtime for an XS sub**: The auto `.so`
  didn't load. Run with `PERLA_DEBUG=1` — look for `[xsloader]` lines.
  If none, check `auto/Foo/Bar/Bar.so` actually exists under `PERLA_LIB`.
- **XS compile fails (undefined reference to `Perl_<foo>`)**: Missing
  macro/function in `perla_perl_compat.h`. Add a stub; see
  [`c_blocks.md`](c_blocks.md) for the conventions.
- **A CPAN module's Perl code fails oddly** (empty return, wrong type):
  Probably a Perla/Perl semantic gap in that specific module. File
  the minimal reproducer — pattern is fix the compat gap then retry.

## File reference

| File | Role |
|---|---|
| `perla/tools/perla-cpan` | This tool (bash) |
| `perla/tools/perla-xs-build` | XS compiler wrapper (bash) |
| `runtime/perla_perl_compat.h` | Perl C API shim (grows as modules need it) |
| `runtime/perla_xsloader.{c,h}` | Runtime XS dispatch + dlopen |
| `runtime/perla_stash.c` | Package/method dispatch, auto-build, require |
| `lib/Perla/Parser.strada` | Compile-time auto-build heuristic (~line 1585) |
