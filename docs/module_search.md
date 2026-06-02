# Module search paths in Perla

Perla has **two separate search paths** for resolving `use Module::Name`
and `require Module`:

- **Compile-time**: consulted when Perla's parser encounters `use X`
  and has to decide whether to inline the module's source, emit a
  link to a precompiled `.pm.o`, or defer to runtime.
- **Runtime**: baked into the compiled executable. Consulted when the
  running program does `require` (either explicit Perl `require`, or
  lazy loads triggered by method dispatch on an empty stash).

They're kept separate deliberately. Compile-time search is
**selective** — big CPAN trees like `/opt/bzperl/lib/site_perl/` are
*not* on the default compile path, because putting them there would
balloon compile time by transitively parsing every module they touch.
Runtime search can be broader without the same penalty.

## Compile-time path

Built by `_build_lib_paths` in `perla/perla.strada`. In search order:

1. **Directory of the input file**. For `./perla scripts/foo.pl`,
   `scripts/` is search position 1 — so sibling `.pl`/`.pm` files
   are always reachable.
2. **Current directory** (`.`). Matches how `perl` resolves relative
   module paths before taint mode.
3. **`$PERLA5LIB`** env var, colon-separated.
4. **`$PERL5LIB`** (Perl compat), colon-separated.
5. **`$HOME/perla/lib`** if it exists.
6. **`-I path`** / **`-Ipath`** CLI flags — prepended, so they beat
   everything else.
7. **`use lib '...';`** statements — added as the parser encounters
   them, so modules loaded after the `use lib` see the new path but
   modules loaded before it don't.

Intentionally **not** in the default list:

- `/opt/bzperl/lib/...` or any CPAN tree. Comment in the code
  explains: "putting /opt/bzperl/lib/site_perl at compile time
  would trigger transitive source parsing of the entire /opt/bzperl
  module tree and blow compile time up to 10+ minutes for large
  real-world programs."

If you need a CPAN tree at compile time:

- Add a `use lib "/opt/..."` statement at the top of your `.pl`, **or**
- Set `$PERL5LIB=/opt/...` in your shell before running `perla`, **or**
- Pass `-I /opt/...` on the command line.

### What happens when a module is found

Once a path matches, Perla's next decision depends on whether the
directory looks like a "library tree" (heuristic: contains
`site_perl` or starts with `/opt`):

| Location | Cache present? | Action |
|---|---|---|
| Non-tree (project lib) | — | Inline the source |
| Tree + `.pm.o` exists | Yes | Emit call into `.pm.o`, link it at the gcc step |
| Tree + `.pm.so` exists and `--shared` | Yes | Emit dlopen at startup |
| Tree + no cache + heuristic match (`sub import`, `our @EXPORT`, etc.) | No | Auto-build `.pm.o` via recursive `perla -M`, then emit call |
| Tree + no cache + no heuristic match | No | Defer to runtime require |

See [`compiling.md`](compiling.md) for the narrow auto-build heuristic
details.

### Not found at compile time

If none of the paths has the file, Perla records nothing and moves
on. If the program tries to actually *call* the module's methods at
runtime, it'll fall through to the runtime require path (below).
Under `--debug`, you'll see:

```
[perla]   Foo::Bar: NOT FOUND at compile time (runtime require will retry)
```

This is normal — many modules that only matter at runtime live in
large CPAN trees that aren't on the compile path.

## Runtime path

Installed inside the compiled executable via
`perla_require_set_paths` (source: `runtime/perla_stash.c`).
Consulted by:

- Explicit `require "Foo/Bar.pm"` / `require Foo::Bar` at runtime.
- Lazy-load triggered by `perla_method_resolve` when it can't find a
  method in an empty stash (e.g. `$obj->dispatch(...)` where the
  package was never loaded).

Sources, in order:

1. The paths baked in at compile time (what `_build_lib_paths`
   produced, minus the file-specific prefix).
2. **`$PERLA_LIB`** env var at runtime (colon-separated, if set).
3. **`lib_path`** from `~/.perla/perla.conf` (if present).
4. **`lib_path`** from `/etc/perla.conf` (if present).

Each path added also gets two probes for **archlib** subdirs:

- `$path/x86_64-linux`
- `$path/x86_64-linux-gnu-thread-multi`

If they exist, they're added too. This is how XS stubs like
`/opt/bzperl/lib/site_perl/5.42.0/x86_64-linux/Date/Calc/XS.pm` get
discovered.

Also probed:

- `$PERL5LIB` (still honored).
- `lib/` and `.` as last-resort fallbacks.

### Runtime require flow

When the program hits `require Foo::Bar`:

1. Translate `Foo::Bar` to `Foo/Bar.pm`.
2. Walk the runtime search path; the first hit is kept.
3. If `Foo/Bar.pm.so` exists, `dlopen` it and call
   `perla_mod_init_Foo_Bar()`.
4. Otherwise, compile on demand: spawn `perla -M <path>` (with
   `PERLA_BUILD_PM_SO=1` so the result is a `.pm.so`), then `dlopen`
   that.
5. If it looks like an XS module (has an `auto/Foo/Bar/Bar.so`
   sibling), **dlopen that `.so` and call `boot_Foo__Bar`** to
   register the XS subs — then mark the module loaded without
   compiling the `.pm`. Direct calls like `Foo::Bar::sym()` work
   from here; `use Foo::Bar qw(sym)` imports need the `.pm` to
   actually run (compile-time path — see below).

   For compile-time `use Foo::Bar`, the narrow auto-build heuristic
   (line ~1585 of `Perla/Parser.strada`) recognizes `.pm` stubs with
   `XSLoader::load` / `DynaLoader::bootstrap` / `our @EXPORT*` and
   compiles them in-tree. The `.pm`'s top-level code then runs at
   program init, setting `@EXPORT_OK` and triggering our
   `XSLoader::load` hook to register XS subs. That's what enables
   `use Foo::Bar qw(sym)` followed by unqualified `sym(...)`. See
   [`cpan.md`](cpan.md) for the end-to-end flow.

Under `--debug` the whole flow traces as:

```
[require] searching 12 runtime paths for Foo/Bar.pm
[require]   found: /opt/bzperl/.../Foo/Bar.pm
[require] loading precompiled /opt/bzperl/.../Foo/Bar.pm.so
[require] init: perla_mod_init_Foo_Bar OK
```

Or on a cache miss:

```
[require] compiling: /path/perla -M /.../Foo/Bar.pm 2>&1
[require]   Compiled /.../Foo/Bar.pm.o (module: Foo::Bar, init: perla_mod_init_Foo_Bar)
[require] loading precompiled /.../Foo/Bar.pm.so
```

## Dedup & cycles

Two layers of dedup prevent re-parsing the same file twice during a
compile:

- **Name-keyed** (`loaded_modules`): `use Foo::Bar` twice gets caught
  by matching the module name.
- **Path-keyed** (`loaded_paths`): if two different `use` statements
  resolve to the same file (e.g. `use Abe::Template` and a later
  `use Template` that hits the same `lib/Abe/Template.pm` due to
  search-path overlap), the second is skipped.

Both are threaded through every recursive parse, so dedup is global
across the whole compile, not per-parse.

Additionally, `perla -M` auto-build invocations are guarded by
`PERLA_BUILDING_LIST`, a colon-separated env var tracking the chain
of in-progress target files. A child compile that tries to rebuild
something already in the chain bails out — fixes fork-bomb cycles
(DateTime::Set ↔ DateTime::Span and similar).

## Worked example

Structure:

```
/home/user/myapp/
├── app.pl                         # entry point
└── lib/
    ├── MyApp/
    │   ├── App.pm
    │   ├── Bootstrap.pm
    │   ├── Template.pm
    │   └── DB/
    │       ├── User.pm
    │       └── Network/
    │           └── SiteMapping.pm
    └── DBIx/Class/Bootstrap/Simple.pm
```

`app.pl` starts with:

```perl
use lib '/opt/bzperl/lib/site_perl/5.42.0';
use lib '/home/user/myapp/lib';
use MyApp::App;
```

At compile time, Perla's search:

1. `myapp/` (input-file dir) → no `MyApp/App.pm` here, move on
2. `.` → no match
3. (`PERL5LIB` empty)
4. After the two `use lib` statements, path list becomes:
   - `myapp/`, `.`, `/opt/bzperl/lib/site_perl/5.42.0`,
     `/home/user/myapp/lib`
5. `use MyApp::App` → `/home/user/myapp/lib/MyApp/App.pm` hit →
   since it's not a "tree" path (no `site_perl`), inline the source.

Inside `MyApp::App.pm`:

```perl
use MyApp::DB::User;     # tries /myapp/lib/MyApp/DB/User.pm — hit, inline
use Template;            # tries /myapp/lib/Template.pm — miss,
                         # then /opt/bzperl/.../Template.pm — hit,
                         # that's a tree path, so emit a call into
                         # precompiled Template.pm.o if it exists,
                         # else check the narrow-auto-build heuristic
                         # (does Template.pm have `sub import`? yes),
                         # then spawn `perla -M /opt/bzperl/.../Template.pm`
                         # and link the resulting .pm.o.
```

At link time, the generated `e.c` has a header comment:

```c
/* PERLA_LINK_OBJECTS: /opt/bzperl/.../Template.pm.o
                       /opt/bzperl/.../Exporter.pm.o
                       /opt/bzperl/.../Carp.pm.o
                       ... */
```

Perla's driver parses this, resolves each `.pm.deps` transitively,
and hands the full `.pm.o` list to gcc as part of the `[cc]`
command. Under `--debug` the full cc line is printed verbatim and
can be replayed by hand.

## Debugging resolution

When something unexpectedly loads (or fails to load), run with:

```bash
PERLA_DEBUG=1 ./perla script.pl 2>&1 | less
```

Every `use` produces a trace line. The output is verbose on large
programs (a real-world app with deep CPAN dependencies produced 727
`use` events during one compile — 299 distinct modules, 428 dedup
skips), but greppable.

To *count* events:

```bash
PERLA_DEBUG=1 ./perla script.pl 2>&1 | grep "^\[perla\]" | \
  awk -F': ' '{print $2}' | awk '{print $1}' | sort | uniq -c
```

To find the top duplicated `use`s (often a sign of a crowded header
or misplaced `use base`):

```bash
PERLA_DEBUG=1 ./perla script.pl 2>&1 | grep "^\[perla\] use " | \
  awk '{print $3}' | sort | uniq -c | sort -rn | head
```
