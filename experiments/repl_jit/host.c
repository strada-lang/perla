/* Phase 0 harness for the REPL JIT rework (docs/repl_jit_plan.md).
 *
 * Proves the core mechanism, end to end, with zero perla codegen changes:
 *   - a PERSISTENT host process holds a shared "pad" (StradaValue* hash);
 *   - each "line" is compiled to a tiny .so (gcc -shared -fPIC -fuse-ld=lld);
 *   - the .so is dlopen'd and its entry symbol called;
 *   - the .so reads/writes the host's pad via host-exported symbols
 *     (host is linked -rdynamic, .so loaded RTLD_GLOBAL), so state persists
 *     across loads WITHOUT re-running prior snippets.
 *
 * If this works, the only remaining hard part for the real REPL is a codegen
 * mode that binds `my`/`our` vars to the pad (Phase 2) — the dlopen/persist
 * plumbing is settled here.
 *
 * Build + run: ./build.sh
 */
#include "strada_runtime.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifndef RUNTIME_INC
#define RUNTIME_INC "/usr/local/lib/strada/runtime"
#endif

/* ---- the persistent pad: name -> StradaValue*. Exported via -rdynamic so
 *      every dlopen'd snippet resolves these against the host. -------------- */
StradaValue *jit_pad = NULL;

void jit_pad_set(const char *name, StradaValue *v) {
    /* take ownership of the (freshly created) value */
    strada_hv_store_take(jit_pad, name, v);
}
StradaValue *jit_pad_get(const char *name) {
    /* borrowed ref out of the pad (NULL if absent) */
    return strada_hv_fetch(jit_pad, name);
}

typedef StradaValue *(*jit_entry_fn)(void);

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000.0 + t.tv_nsec / 1.0e6;
}

/* Compile `body` into void-entry .so `jit_eval_N`, dlopen, call it.
 * Returns the entry's StradaValue* (last-expression value, may be NULL). */
static StradaValue *eval_snippet(int n, const char *body) {
    char cpath[256], sopath[256], sym[64], cmd[2048];
    snprintf(cpath,  sizeof cpath,  "/tmp/jit_snip_%d.c",  n);
    snprintf(sopath, sizeof sopath, "/tmp/jit_snip_%d.so", n);
    snprintf(sym,    sizeof sym,    "jit_eval_%d", n);

    FILE *f = fopen(cpath, "w");
    if (!f) { perror("fopen"); return NULL; }
    fprintf(f,
        "#include \"strada_runtime.h\"\n"
        "extern StradaValue *jit_pad;\n"
        "extern void jit_pad_set(const char*, StradaValue*);\n"
        "extern StradaValue *jit_pad_get(const char*);\n"
        "StradaValue *%s(void) {\n%s\n}\n",
        sym, body);
    fclose(f);

    double t0 = now_ms();
    snprintf(cmd, sizeof cmd,
        "gcc -shared -fPIC -O0 -w -fuse-ld=lld -I\"%s\" -o \"%s\" \"%s\" 2>&1",
        RUNTIME_INC, sopath, cpath);
    int rc = system(cmd);
    double t_compile = now_ms() - t0;
    if (rc != 0) { fprintf(stderr, "[snip %d] compile failed\n", n); return NULL; }

    double t1 = now_ms();
    void *h = dlopen(sopath, RTLD_NOW | RTLD_GLOBAL);
    if (!h) { fprintf(stderr, "[snip %d] dlopen: %s\n", n, dlerror()); return NULL; }
    jit_entry_fn fn = (jit_entry_fn)dlsym(h, sym);
    if (!fn) { fprintf(stderr, "[snip %d] dlsym: %s\n", n, dlerror()); return NULL; }
    StradaValue *r = fn();
    double t_load = now_ms() - t1;
    /* intentionally never dlclose(h): keep snippet symbols (subs) resolvable */

    fprintf(stderr, "[snip %d] compile %.1f ms  dlopen+call %.2f ms\n",
            n, t_compile, t_load);
    return r;
}

int main(void) {
    jit_pad = strada_new_hash();

    fprintf(stderr, "=== persistent-host JIT pad demo ===\n");

    /* line 1: my $x = 42;   (no re-run of anything; state goes to the pad) */
    eval_snippet(1, "jit_pad_set(\"x\", strada_new_int(42)); return NULL;");

    /* line 2: my $y = $x * 2;   (reads pad['x'] written by a DIFFERENT .so) */
    eval_snippet(2,
        "StradaValue *x = jit_pad_get(\"x\");\n"
        "    long v = strada_to_int(x);\n"
        "    jit_pad_set(\"y\", strada_new_int(v * 2)); return NULL;");

    /* line 3: my $s = \"y=\" . $y;   (string build + store) */
    eval_snippet(3,
        "StradaValue *y = jit_pad_get(\"y\");\n"
        "    char buf[64]; snprintf(buf, sizeof buf, \"y=%ld\", (long)strada_to_int(y));\n"
        "    jit_pad_set(\"s\", strada_new_str(buf)); return NULL;");

    /* line 4: print $s;   (read it back in yet another .so) */
    eval_snippet(4,
        "StradaValue *s = jit_pad_get(\"s\");\n"
        "    char *cs = strada_to_str(s); printf(\"OUT: %s\\n\", cs); free(cs); return NULL;");

    /* verify from the host side too */
    StradaValue *y = jit_pad_get("y");
    StradaValue *s = jit_pad_get("s");
    char *cs = s ? strada_to_str(s) : NULL;
    fprintf(stderr, "host sees: y=%ld  s=\"%s\"  %s\n",
            y ? (long)strada_to_int(y) : -1, cs ? cs : "(nil)",
            (y && strada_to_int(y) == 84 && cs && strcmp(cs, "y=84") == 0)
                ? "=> PASS (state persisted across 4 separate .so loads)"
                : "=> FAIL");
    if (cs) free(cs);
    return 0;
}
