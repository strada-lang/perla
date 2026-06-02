# perl_php benchmark suite

Compares **perla** (Perl 5 → C, compiled native) against **Perl** and **PHP** on
the same workloads. Each workload is implemented identically in Perl (`*.pl`,
which perla compiles) and PHP (`php/*.php`); the harness verifies all three print
byte-identical output before timing.

## Run

```bash
./run.sh            # builds perla -O2 binaries, verifies output, times all three
PERLA_BIN=/path/to/perla ./run.sh
```

Reports the **min of 3 runs** (total process time, incl. interpreter startup).
perla is compiled `-O2` to a native binary; `perl`/`php` are the system CLIs.

## Workloads

| file | exercises |
|------|-----------|
| `fib.pl` | recursion / function-call overhead (`fib(35)`) |
| `strings.pl` | string concat + regex `s///` (1,000,000 iters) |
| `data.pl` | array push/sum + hash insert/lookup (500,000) |
| `oop.pl` | blessed-object method dispatch (5,000,000 calls) |

## Representative results

perla 0.2 (`-O2`, lld), Perl 5.38, PHP 8.3.6, x86-64 Linux:

| workload | perla | perl | php | perla vs perl | perla vs php |
|----------|------:|-----:|----:|:---:|:---:|
| fib      | 0.392s | 3.006s | 0.347s | 7.7× | 0.9× |
| strings  | 0.100s | 0.242s | 0.119s | 2.4× | 1.2× |
| data     | 0.041s | 0.093s | 0.046s | 2.3× | 1.1× |
| oop      | 0.205s | 0.388s | 0.083s | 1.9× | 0.4× |

**Takeaways:** perla beats Perl on every workload (1.9–7.7×). Against PHP 8.3 it's
roughly a tie overall — ahead on string/array/hash throughput, level on
recursion, behind on OOP-heavy method dispatch.

### On the OOP gap (profiled)

A 5M-call differential isolates the cause:

| | perla | perl | php |
|---|--:|--:|--:|
| empty method call (`$o->m()`) | 0.182s | 0.280s | 0.056s |
| + field access (`$_[0]->{count}++`) | +0.014s | — | +0.025s |

So the gap is **method-call overhead, not field access** — and perla's dispatch
already *beats Perl*; PHP's call path is just exceptionally lean. perla's per-call
cost is its calling convention: `perla_call_push`/`pop` (maintains the call stack
for `caller()`/`die` traces) + `cleanup_mark`/`drain` (leak-free temp management)
+ `@_` refcounting — all with side effects the optimizer can't remove, all
serving correctness. PHP avoids most of it via a bytecode VM with inline caches
and packed object slots. Closing the remaining gap would require a leaner
calling convention (e.g. an opt-in fast path that skips the stack-frame push and
cleanup tracking for simple leaf methods) — a scoped optimization with
correctness trade-offs, tracked separately. (`perla_blessed`, an out-of-line call
on every dispatch, has been inlined.)
