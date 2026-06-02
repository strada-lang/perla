# Perla

Perla is a Perl 5 compiler built on [Strada](https://github.com/strada-lang/strada-lang).
It lexes, parses, and lowers Perl source to Strada AST, which Strada then
compiles to C and native executables. The result is a standalone binary
that runs without libperl.

It is **not** a drop-in replacement for Perl. Think of it as a
Perl-shaped frontend on a compiled runtime — most Perl you'll write
works, but there are corners where Perla's semantics differ or where a
given idiom isn't yet implemented. Expect to hit one every so often in
a 5000-line codebase; every time we've pushed a real-world application
through Perla we've had to patch a few.

## Installation

Perla compiles Perl to C and links the Strada runtime, so it builds
against an installed Strada. Build and install Strada first:

```bash
git clone https://github.com/strada-lang/strada-lang
cd strada-lang
./configure
make
sudo make install        # installs strada to /usr/local
```

Then build Perla — it uses the `strada` on your `PATH` by default:

```bash
git clone https://github.com/strada-lang/perla
cd perla
make
sudo make install        # optional — puts `perla` on your PATH
```

To build against a Strada *source tree* instead of the system install,
pass `STRADA_DIR`: `make STRADA_DIR=/path/to/strada-lang`. If you skip
`make install`, `perla` lives at `./perla` in the build directory.

## Quick start

```bash
# compile + run
./perla hello.pl

# compile to executable, don't run
./perla -o hello hello.pl
./hello

# generate C code only (no executable)
./perla -c -o hello.c hello.pl

# run a one-liner
./perla -e 'print "hi\n"'

# precompile a .pm to .pm.o (and .pm.so if PERLA_BUILD_PM_SO=1)
./perla -M My/Module.pm

# precompile every .pm under a directory (idempotent — skips done)
./perla -M lib/
```

See [`compiling.md`](compiling.md) for the full flag reference,
optimization levels, and cache behavior.

## Documentation

| File | What |
|---|---|
| [`cpan.md`](cpan.md) | Installing CPAN modules with `perla-cpan` (by name, with deps, with XS) |
| [`compiling.md`](compiling.md) | Compile flags, optimization, module cache, `--debug`, `--keep` |
| [`c_blocks.md`](c_blocks.md) | `__C__ { }` escape hatch — drop into raw C from Perl source |
| [`module_search.md`](module_search.md) | How compile-time and runtime paths resolve `use X` and `require` |

## How Perla differs from Perl

Summary; individual docs go deeper. None of these are bugs — they're
design points.

- **Compile-time resolution.** `use Module` is resolved at compile
  time (the module's source is read, parsed, and either inlined or
  emitted as a call into a precompiled `.pm.o`). There's still a
  runtime `require` path, but the default is eager.
- **No `eval STRING` by default.** You can opt in via
  `core::full_eval_on()` or similar helpers, but it shells out to a
  child `perla` compile under the hood. It's slow and not typical
  Perl runtime. `eval BLOCK` (no argument) works normally for
  exception handling.
- **XS modules load via `perla-cpan`.** Install with
  `perla-cpan Foo::Bar` — it fetches from CPAN, compiles the `.xs`
  into `auto/Foo/Bar/Bar.so`, and installs the `.pm`. At runtime,
  Perla's `XSLoader::load` hook dlopens the `.so` and registers the
  XS subs. See [`cpan.md`](cpan.md). Common XS pieces also have
  native Perla implementations built in (regex via PCRE2, JSON, DBI,
  List::Util, Scalar::Util, Encode, Time::HiRes, Storable::dclone).
  Complex XS modules may surface gaps in `perla_perl_compat.h` that
  get filled in per-module.
- **Mostly complete OO.** `bless` / `@ISA` / `SUPER::` / `AUTOLOAD` /
  method resolution order all work, including multiple inheritance.
  `overload` for `""`, `==`, arithmetic ops, etc. works.
- **`format` / `write`.** Perl's text-template report system works,
  including picture fields (`@<<<`, `@>>>`, `@||`, `@###.##`, `@*`),
  multi-line `^<<<` filled fields, the `$~` / `$^` / `$=` / `$-` /
  `$%` / `$^A` format specials, `formline`, `format_TOP` headers with
  pagination, per-filehandle formats via `select`, and `write FH`.
- **`tie` / `untie` / `tied`.** Works on scalars, hashes, arrays, and
  filehandles (`tie *FH, ...` with `READLINE` / `PRINT` / `CLOSE`).
  FETCH/STORE dispatch fires through reads, writes, compound
  assignment (`.=`, `+=`), `++`/`--`, `defined`, `substr`, and list
  construction.
- **Typeglobs & aliasing.** `*A = *B`, `*A = \$x`, `*A = \&sub`,
  `%Pkg::` stash-as-hash iteration, and write-through aliasing all
  work. UTF-8 is character-oriented end to end (`SVf_UTF8` flag),
  with full Unicode normalization (`Unicode::Normalize`, `utf8::nfc`…)
  and `Encode` transcoding for Latin1 / CP1252 / ASCII.
- **DBIx::Class**: a minimal stub handles the common patterns
  (has_one, has_many, belongs_to, ResultSet::search/first/all). It's
  not the real DBIC — it's a re-implementation of its public API
  against Perla's DBI bridge.
- **Moose**: native C runtime implements `has` / `extends` / `with`
  / `before/after/around` / `isa` / `meta` / accessors. Not via
  Class::MOP.
- **Try::Tiny, Carp, Data::Dumper, JSON, YAML, URI::Escape,
  File::Spec, File::Temp, Digest::MD5/SHA, MIME::Base64, HTTP::Date,
  List::Util, Scalar::Util, Time::HiRes** — all work.
- **Drogo** (web framework): mostly works. `Drogo::Server::Cannoli`
  exists for serving through [Cannoli](https://github.com/strada-lang/cannoli).
- **Variables named differently in C.** `$foo` in Perl becomes
  `v_foo` in the emitted C. Matters only when you drop into `__C__`
  blocks. See [`c_blocks.md`](c_blocks.md).

## The test workflow

Every change to Perla (or a `.pm` edit that changes `perla -M` output)
should run:

```bash
make                                    # rebuild perla itself (from the perla repo)
./t/run_tests.sh                        # 159-test regression suite
```

If you're developing against a large real-world app as a target,
run with memory and timeout caps:

```bash
./safe_run.sh --timeout 600 --mem 6G -- \
  ./perla /path/to/your/app.pl
```

See [`compiling.md`](compiling.md) for how to warm the precompile cache
(cuts the compile roughly in half).

## Reporting bugs

For in-house work, paste the failing `perla -M <file.pm>` output or
the gcc error, plus the shortest reproducer Perl snippet. The same
applies when you see a runtime error that looks like "Can't locate
method X" or an empty result from something that should work — paste
stderr and stdout.
