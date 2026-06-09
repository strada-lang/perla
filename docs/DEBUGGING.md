# Debugging perla-compiled programs with gdb

perla compiles your Perl to C, then to a native binary. With the `-g` flag you
get a fully gdb-debuggable executable: DWARF line info, working backtraces, and —
via `#line` directives perla emits — gdb maps straight to your **original Perl
source**. `break myprog.pl:42`, `list`, `step`, and backtraces all show the
`.pl`. (The generated C is also kept next to the binary for reference.)

```bash
perla -g -o myprog myprog.pl     # build with debug info; keeps myprog.c
gdb ./myprog
```

`-g` (alias `--debug-symbols`) does three things:

1. Adds `-g` to the C compiler so DWARF debug info is emitted (7 `.debug_*`
   ELF sections).
2. Keeps var-tracking and async unwind tables on. (The default build turns these
   off — `-fno-var-tracking -fno-asynchronous-unwind-tables` — for speed and
   smaller binaries, which is why ordinary `perla` binaries can't show locals or
   reliable backtraces even though they keep a symbol table.)
3. Emits `#line N "yourfile.pl"` directives before each statement's generated C,
   so the DWARF line table maps back to your **Perl** source — `break file.pl:N`,
   `list`, `step`, and backtraces all show the `.pl`. (A few statement kinds
   whose AST node lacks a line — e.g. a bare `return` or implicit param binding —
   map to the nearest preceding line.)
4. Implies `--keep`, so the generated `<base>.c` stays next to the binary for
   reference (e.g. to see exactly what C a statement expands to).

Without `-g`, default binaries are *not* stripped — `.symtab` is present, so you
can still set breakpoints by C symbol name — but there's no DWARF, so no source
lines, locals, or args.

## Name mapping: Perl → generated C

Source view, breakpoints (`break file.pl:N`), and backtraces are in terms of your
Perl. But **values** are still inspected with the C names perla emits — every
Perl value is a `StradaValue *`, so you read it via the name map below plus
`strada_to_str` (see further down). The mapping is mechanical:

| Perl                     | C symbol                         |
|--------------------------|----------------------------------|
| `sub greet { … }`        | `perla_sub_main_greet`           |
| `sub Foo::bar { … }`     | `perla_sub_Foo_bar`              |
| package `main`           | `main_` package prefix           |
| `my $foo` / `our $foo`   | `v_foo`                          |
| `my @items`              | `v_items__a`                     |
| `my %opts`               | `v_opts__h`                      |
| anonymous sub            | `perla_sub_main___perla_anon_N`  |
| top-level program body   | `perla_main` / `main`            |

Every Perl value is a `StradaValue *`. Integers may be *tagged* (encoded in the
pointer, odd address) — don't dereference them raw. To print a scalar's value
from gdb, call the runtime stringifier:

```gdb
(gdb) call (char*)strada_to_str(v_foo)
$1 = 0x... "hi world"
```

`strada_to_str` returns a malloc'd C string (it leaks the one copy gdb makes —
harmless in a debug session). `strada_to_int(v_foo)` / `strada_to_num(v_foo)`
return plain values and handle tagged ints transparently.

## Typical session

```gdb
$ perla -g -o myprog myprog.pl
$ gdb ./myprog
(gdb) break perla_sub_main_greet      # break on `sub greet`
(gdb) run
(gdb) bt                              # backtrace (unwind tables on under -g)
(gdb) list                            # show the generated C around here
(gdb) info args                       # @_ comes in as the args struct
(gdb) call (char*)strada_to_str(v_n)  # inspect a lexical $n
(gdb) continue
```

To break in the program's top-level code, use `break perla_main` (or `main`).

## Tips

- **Find the C name fast:** compile with `-g` (or `--keep`), then
  `grep perla_sub_ myprog.c` to see every sub's mangled name.
- **Crashes / "stack overflow":** perla installs a `SA_ONSTACK` SIGSEGV handler
  that prints "stack overflow (likely deep recursion)" — which can *mask* an
  ordinary segfault. Set `PERLA_NO_STACK_GUARD=1` to disable it so gdb (or
  valgrind) sees the real faulting frame.
- **valgrind:** `PERLA_NO_STACK_GUARD=1 valgrind --leak-check=full --num-callers=25 ./myprog`.
- **Optimized builds:** `-g` works with any `-O` level, but at `-O2`+ the
  optimizer inlines and reorders, so prefer the default `-O0` while debugging.
