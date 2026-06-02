# `__C__` blocks in Perla

Inside a Perla-compiled `.pl` or `.pm`, `__C__ { ... }` drops raw C
into the generated output. The block is emitted **verbatim** — Perla
doesn't parse or rewrite it. Use it for: FFI calls into native
libraries, inline performance-critical numeric code, runtime tricks
that need `dlopen` / `pthread_*` / `clock_gettime`, or initializing
C-only globals.

Same feature as Strada's `__C__`, usable from Perl source compiled
through Perla.

## Three valid positions

### File scope

```perl
# At the top level of your .pl / .pm, outside any sub.
__C__ {
    #include <unistd.h>
    #include <sys/mman.h>

    /* module-private globals */
    static int call_counter = 0;
    static struct {
        int fd;
        void *mmap_base;
    } g_state = { -1, NULL };

    /* helper — only visible within this compilation unit */
    static int pick_buffer_size(int hint) {
        return hint > 0 && hint < 1 << 20 ? hint : 4096;
    }
}
```

This gets emitted near the top of the generated `.c`, before function
definitions. Use it for `#include`s you need across multiple sub
bodies, file-scope `static` state, and C helpers you'll call from
other `__C__` blocks.

### Inside a sub

```perl
sub add {
    my ($a, $b) = @_;
    my $sum = 0;
    __C__ {
        int64_t __a = strada_to_int(v_a);
        int64_t __b = strada_to_int(v_b);
        strada_decref(v_sum);
        v_sum = strada_new_int(__a + __b);
    }
    return $sum;
}
```

Emitted as a `{ ... }` block inside the generated C function body.

### Inside an expression (statement-expression form)

```perl
sub pid {
    my $p = __C__ {
        /* GCC statement-expression */
        ({
            StradaValue *__r = strada_new_int((int64_t)getpid());
            __r;  /* last expression is the value */
        })
    };
    return $p;
}
```

You're leaning on `({ ... })` (a GCC extension). The last expression
inside the braces is the value. Only works with gcc/clang — but since
Perla drives gcc, that's fine.

## Variable name mapping — the gotcha

Perl identifiers become C identifiers with a sigil-derived prefix:

| Perl | C (Perla-generated) |
|---|---|
| `$foo` | `v_foo` |
| `@arr` | `v_arr` |
| `%hash` | `v_hash` |
| `@_` | `perla_at_` |
| `$_` | `perla_dollar_underscore` |
| `$1`..`$9` | `strada_capture_var(N)` (function call, not lvalue) |
| `$!` | `strerror(errno)` (read) / `errno = N` (write) |
| `$/` | `perla_irs` |
| `$\ ` | `perla_ors` |
| `$,` | `perla_ofs` |
| `$|` | `__perla_autoflush` (`int`) |
| `$$` | `getpid()` |
| `$0` | `perla_dollar_zero` |
| `$^W` | `v__caret_W` |
| `$^O` | `v__caret_O` |
| `$^V` | `v__caret_V` |
| `$^X` | `v__caret_X` |
| `$]` | `v__rbrack_` |
| `$AUTOLOAD` | `perla_get_autoload_var()` (function call) |
| `$a` / `$b` (in sort) | `v_a` / `v_b` (or `@_[0]` / `@_[1]` inside a comparator) |
| Fully-qualified `$Pkg::x` | `perla_scalar_get("Pkg", "x")` — use via the stash, not a C static |
| Fully-qualified `%Pkg::x` | `perla_hash_get("Pkg", "x")` |
| Fully-qualified `@Pkg::x` | `perla_array_get("Pkg", "x")` |

Collision-marked names (when the same base name is declared with two
sigils at file scope) get suffixes:

| Perl | C |
|---|---|
| `%foo` (collision) | `v_foo__h` |
| `@foo` (collision) | `v_foo__a` |

Check the generated C with `--keep` if you're unsure what name Perla
picked.

**The block is copied byte-for-byte.** Perla does *not* substitute
`$x` → `v_x` inside. Write the C name directly.

## What you have access to

### StradaValue helpers (runtime — `strada_runtime.h`)

| Pattern | What |
|---|---|
| `strada_to_int(sv)` | `int64_t`, handles tagged ints transparently |
| `strada_to_num(sv)` | `double` |
| `strada_to_str(sv)` | **malloc'd `char*` — caller must `free()`** |
| `strada_to_str_buf(sv, buf, size)` | writes into a caller buffer, returns `const char*` (no alloc) |
| `strada_new_int(n)` | `StradaValue*` with refcount 1 (tagged int where possible) |
| `strada_new_num(d)` | boxed number |
| `strada_new_str(s)` | str — copies the input |
| `strada_new_str_len(s, n)` | str with explicit length (binary-safe) |
| `strada_new_undef()` | undef |
| `strada_new_array()` / `strada_new_hash()` | empty containers |
| `strada_new_ref(inner, sigil)` | `\X` — sigil is `'$'` / `'@'` / `'%'` |
| `strada_incref(sv)` / `strada_decref(sv)` | refcount bookkeeping (no-ops on tagged ints) |
| `STRADA_IS_TAGGED_INT(sv)` | test macro — always check before `sv->type` / `sv->value` |
| `STRADA_TAGGED_INT_VAL(sv)` | extract int value |
| `STRADA_MAKE_TAGGED_INT(n)` | encode directly |
| `strada_array_push(av, elem)` / `strada_array_push_take(av, elem)` | push to array; `_take` hands off ownership |
| `strada_hv_store(hv, key, val)` / `strada_hv_store_take(hv, key, val)` | same for hashes |
| `strada_hv_fetch_owned(hv, key)` | returns an owned ref (incref'd) |
| `strada_hash_get(hv, key)` | borrowed ref (no incref) |
| `strada_deref_array(sv)` / `strada_deref_hash(sv)` | unwrap a ref |

### perla_* helpers (Perl semantics layer)

| Pattern | What |
|---|---|
| `perla_bless(ref, "Pkg")` | set blessed package |
| `perla_blessed(sv)` | read blessed name (`const char*` or `NULL`) |
| `perla_class_name(sv)` | bless-semantic class resolution (handles blessed-ref `$class` arg) |
| `perla_method_dispatch(obj, "method", args)` | full Perl method lookup |
| `perla_super_dispatch(obj, cur_pkg, "method", args)` | `SUPER::method` |
| `perla_try_autoload(pkg, method, obj, args)` | AUTOLOAD fallback |
| `perla_scalar_get / set (pkg, name)` | package-scoped scalar through stash |
| `perla_hash_get / set (pkg, name)` | same for hash |
| `perla_array_get / set (pkg, name)` | same for array |
| `perla_code_get (pkg, name)` | look up a sub by name (returns a string for dlsym) |
| `perla_isa_push(sub, super)` | push onto `@ISA` |
| `perla_call_code(code, args)` | invoke a code slot |
| `perla_eval_error` | `$@` as a `StradaValue *` (thread-local-ish) |
| `perla_call_push(pkg, sub, file, line)` / `perla_call_pop()` | manage the call frame stack |

### DBI bridge (`perla_dbi.h`)

| Pattern | What |
|---|---|
| `perla_dbi_connect(dsn, user, pass)` | `DBI->connect`, returns a blessed `DBI::db` |
| `perla_dbi_prepare(dbh, sql)` | prepare a statement handle |
| `perla_dbi_execute(sth, binds)` | execute with bind params |
| `perla_dbi_fetchrow_hashref(sth)` / `perla_dbi_fetchrow_array(sth)` | fetch |
| `perla_dbi_selectrow_array / selectall_arrayref / selectcol_arrayref (dbh, sql, binds)` | one-shot query helpers |
| `perla_dbi_do(dbh, sql, binds)` | execute a non-query |
| `perla_dbi_disconnect(dbh)` | close |

## Memory rules

Four rules cover 90% of bugs.

### 1. Tagged-int check before dereferencing

Integers in the valid range are encoded directly in the pointer. Any
code that reads `sv->type`, `sv->value`, `sv->meta`, or `sv->refcount`
must first check `STRADA_IS_TAGGED_INT(sv)`:

```c
if (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type == STRADA_STR) {
    /* safe to read sv->value.pv */
}
```

If you only use the high-level helpers (`strada_to_int`,
`strada_to_str`, `strada_new_*`), they handle it internally.

### 2. `strada_to_str` allocates

```c
char *s = strada_to_str(sv);     /* allocates */
use_it(s);
free(s);                         /* always free */
```

If you don't want to allocate:

```c
char buf[256];
const char *s = strada_to_str_buf(sv, buf, sizeof(buf));
/* `s` points into `buf`; no free needed */
```

### 3. Decref before reassign

If you own a `StradaValue*` (e.g. a local you created, or one you
incref'd), release it before overwriting:

```c
strada_decref(v_result);
v_result = strada_new_int(42);
```

Forgetting leaks. Decrefing something you didn't own (double-free) is
worse.

### 4. `_take` vs plain for container inserts

When inserting a freshly allocated value into a hash or array, use the
`_take` variants to avoid an extra refcount:

```c
/* BAD: strada_new_str returns refcount=1, store increfs to 2, later
   decref drops to 1 and the string leaks. */
strada_hv_store(hv, "k", strada_new_str("v"));

/* GOOD: store takes ownership, keeps refcount at 1. */
strada_hv_store_take(hv, "k", strada_new_str("v"));

/* Plain store is correct when the value is already owned by someone
   else (e.g. a variable you don't want to give up): */
strada_hv_store(hv, "k", v_existing);   /* increfs v_existing */
```

Same distinction for `strada_array_push` / `strada_array_push_take`.

## Things to avoid

- **Calling `strada_to_str` inside a function argument list** without
  capturing the result — you leak every time. Wrap in a
  statement-expression:

  ```c
  /* BAD: */
  printf("%s\n", strada_to_str(sv));

  /* GOOD: */
  ({ char *__s = strada_to_str(sv); printf("%s\n", __s); free(__s); });
  ```

- **Stringifying a hash or array in a format specifier.**
  `strada_to_str` on a container returns `"HASH(0x…)"` / `"ARRAY(0x…)"`
  — usually not what you wanted. Iterate instead.

- **Holding a pointer across a GC boundary.** Reference counts are
  decremented eagerly, so a `StradaValue *` obtained from
  `strada_hash_get` (borrowed) is only valid until the hash is mutated
  or freed. If you need to hold it, incref it.

- **Using `\n` or other C escapes in a Perl string literal and
  expecting Perla to translate.** The literal is a *Perl* string
  literal — Perla handles escapes during parse. `__C__` is where you
  emit C, so use C conventions.

## Worked example — FFI to `getrusage`

```perl
use strict;
use warnings;

__C__ {
    #include <sys/resource.h>
    #include <sys/time.h>
}

sub rss_bytes {
    my $r = 0;
    __C__ {
        struct rusage __u;
        if (getrusage(RUSAGE_SELF, &__u) == 0) {
            /* ru_maxrss is in kilobytes on Linux, bytes on macOS. */
            strada_decref(v_r);
            v_r = strada_new_int((int64_t)__u.ru_maxrss * 1024);
        }
    }
    return $r;
}

printf "RSS: %d MB\n", int(rss_bytes() / 1024 / 1024);
```

## Worked example — promoting an in-flight `.so` to RTLD_GLOBAL

This one's from `cannoli_perla.strada` in the Cannoli-Perla bridge.
Cannoli `dlopen`s libraries with `RTLD_LAZY` (no `GLOBAL`), which
means subsequent `.so`'s can't see our symbols. Re-open with
`RTLD_NOLOAD | RTLD_GLOBAL` to promote the existing mapping's scope:

```perl
func cannoli_init(str $config) int {
    __C__ {
        #include <dlfcn.h>
        Dl_info __di;
        if (dladdr((void*)cannoli_init, &__di) && __di.dli_fname) {
            void *__self = dlopen(__di.dli_fname,
                                  RTLD_NOW | RTLD_GLOBAL | RTLD_NOLOAD);
            if (!__self) {
                fprintf(stderr, "self-promote failed: %s\n", dlerror());
            }
        }
    }
    # ... rest of init in Perl ...
}
```

`dladdr` is GNU-only but fine on Linux; gives us the `.so`'s own path
so we can re-`dlopen` ourselves.

## When to use `__C__` vs plain Perl

Use `__C__` when:

- You need a syscall or libc call that Perla doesn't wrap
(`mmap`, `ioctl`, `pthread_*`, `clock_gettime`, `getrusage`, …).
- You're pulling a C library's functions that Perl doesn't otherwise
  surface (libcurl, zstd, a custom `.so`, etc.).
- You're optimizing a hot numeric inner loop and the overhead of
  `strada_new_int` / `strada_to_int` boxing dominates.
- You're bridging between Perla and another Strada / C-ABI library
  where speaking the ABI directly is cleaner than marshalling through
  Perl.

Don't use `__C__` when:

- You're reaching for a Perl builtin Perla already implements
  (`print`, `sprintf`, regex, `keys`, `values`, …). They're faster
  than anything you'll hand-write, and type-safe.
- You're working with untyped / varying-type data. The boxing you'd
  skip in `__C__` comes back the moment you need to return to Perl.

## See also

- `CLAUDE.md` at the Strada repo root — the Strada language's own
  `__C__` documentation (same mechanism, same helpers).
- `cannoli/lib/perla/cannoli_perla.strada` — a real
  bridge using `__C__` for `dlopen` + self-promotion.
- `runtime/perla_stash.c` / `runtime/perla_dbi.c` —
  source for the `perla_*` helpers documented above.
