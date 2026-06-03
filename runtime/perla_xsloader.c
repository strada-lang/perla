/*
 * perla_xsloader.c — Runtime XSLoader / DynaLoader bootstrap for Perla
 *
 * See perla_xsloader.h for the architectural overview.
 *
 * This file is the ONE that defines storage for the shared XS stack
 * state (perla_stack, perla_sp, perla_markstack, perla_markstack_ptr,
 * perla_interp, the immortal SVs). Every other consumer of
 * perla_perl_compat.h — including XS .so files loaded at runtime —
 * sees those as externs and resolves them to this file's instance
 * via RTLD_GLOBAL (perla is linked with -rdynamic).
 */

#define _GNU_SOURCE
#define PERLA_XS_STATE_OWNER   /* Must precede the header include */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "strada_runtime.h"
#include "perla_stash.h"
#include "perla_perl_compat.h"
#include "perla_xsloader.h"

/* From perla_stash.c — lazy-init the require search paths + global state.
 * Note: g_INC_hash is static in perla_stash.c, so we can't extern it.
 * The %INC seeding for XSLoader.pm / DynaLoader.pm is done in perla_init
 * directly (perla_stash.c) instead of here. */
extern void perla_require_ensure_paths(void);
extern char **g_require_paths;
extern size_t g_require_path_count;
extern int perla_debug_mode(void);

/* ============================================================
 * perla_xsub_new / perla_is_xsub — XSUB-marked CPOINTER helpers
 * ============================================================ */

StradaValue *perla_xsub_new(void (*xs_fn)(void*)) {
    StradaValue *sv = strada_cpointer_new((void*)xs_fn);
    if (!sv) return NULL;
    /* strada_ensure_meta is static-inline in strada_runtime.c so we
     * allocate the meta ourselves. The meta is freed by strada_free_value
     * when refcount hits zero. */
    if (!sv->meta) {
        sv->meta = calloc(1, sizeof(StradaMetadata));
    }
    if (sv->meta) {
        if (sv->meta->struct_name) free(sv->meta->struct_name);
        sv->meta->struct_name = strdup("XSUB");
    }
    return sv;
}

int perla_is_xsub(StradaValue *sv) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return 0;
    if (sv->type != STRADA_CPOINTER) return 0;
    if (!sv->meta || !sv->meta->struct_name) return 0;
    return strcmp(sv->meta->struct_name, "XSUB") == 0;
}

/* ============================================================
 * perla_xs_invoke — bridge Perla-convention args → XS stack
 * ============================================================ */

StradaValue *perla_xsub_invoke(void (*xs_fn)(void*), StradaValue *args) {
    if (!xs_fn) return strada_new_undef();

    /* Record where our mark should go — one past current sp.
     * After pushing args, sp - perla_stack = mark_idx + n.
     * dXSARGS then computes ax = TOPMARK + 1 = mark_idx + 1.
     * So ST(0) = perla_stack[ax + 0] = perla_stack[mark_idx + 1] = first arg. */
    long mark_idx = (long)(perla_sp - perla_stack);

    /* Push the mark */
    if ((perla_markstack_ptr - perla_markstack) + 1 >= 255) {
        /* Markstack overflow — refuse to avoid corruption */
        return strada_new_undef();
    }
    *++perla_markstack_ptr = (I32)mark_idx;

    /* Push args onto stack as BORROWED references. The caller's args
     * array keeps them alive for the duration of the XS call. Standard
     * XS code doesn't decref its args - it reads via ST(n), and if it
     * wants to hold a reference it explicitly SvREFCNT_inc. XSprePUSH
     * rewinds sp (effectively popping args) without decref, so any
     * incref we did here would be unbalanced. */
    StradaArray *av = NULL;
    if (args) {
        if (!STRADA_IS_TAGGED_INT(args) && args->type == STRADA_ARRAY) {
            av = args->value.av;
        }
    }
    size_t n_args = av ? av->size : 0;
    for (size_t i = 0; i < n_args; i++) {
        if ((perla_sp - perla_stack) + 1 >= PERLA_STACK_SIZE) break;
        StradaValue *v = strada_array_get(av, (int64_t)i);
        *++perla_sp = v;  /* borrowed — args array keeps v alive */
    }

    /* Call the XS function. Reads args via dXSARGS; may push returns
     * back onto perla_stack (typically after XSprePUSH rewind). */
    ((void (*)(void*))xs_fn)(NULL);

    /* Read return values: everything above our mark on the stack */
    long new_top = (long)(perla_sp - perla_stack);
    long nret = new_top - mark_idx;
    if (nret < 0) nret = 0;

    /* Return values were allocated by the XS function (typically via
     * Perl_newSVnv/newSViv/newSVpvn, which start at refcount 1) and
     * pushed onto perla_stack via XPUSHs (which doesn't bump the
     * refcount). So each return slot already holds a ref count of 1
     * that we transfer to the caller. No incref/decref dance needed
     * for the single case, and push_take for the multi case. */
    StradaValue *result;
    if (nret == 0) {
        result = strada_new_undef();
    } else if (nret == 1) {
        result = perla_stack[mark_idx + 1];
        if (!result) result = strada_new_undef();
    } else {
        /* Multiple returns — collect into an array. push_take takes
         * the existing refcount rather than bumping it. */
        result = strada_new_array();
        for (long i = 1; i <= nret; i++) {
            StradaValue *v = perla_stack[mark_idx + i];
            if (v) strada_array_push_take(result->value.av, v);
        }
    }

    /* Clear the stack slots (ownership transferred to `result`). */
    for (long i = 1; i <= nret; i++) {
        perla_stack[mark_idx + i] = NULL;
    }

    /* Restore stack + markstack */
    perla_sp = perla_stack + mark_idx;
    perla_markstack_ptr--;

    return result;
}

/* ============================================================
 * perla_xs_bootstrap_so — dlopen + call boot function
 * ============================================================ */

/* Build boot function name: "Foo::Bar" → "boot_Foo__Bar" */
static void build_boot_name(const char *module, char *out, size_t out_sz) {
    snprintf(out, out_sz, "boot_");
    size_t oi = strlen(out);
    size_t mlen = strlen(module);
    for (size_t i = 0; i < mlen && oi + 3 < out_sz; i++) {
        if (module[i] == ':' && i + 1 < mlen && module[i + 1] == ':') {
            out[oi++] = '_';
            out[oi++] = '_';
            i++;
        } else {
            out[oi++] = module[i];
        }
    }
    out[oi] = '\0';
}

int perla_xs_bootstrap_so(const char *so_path, const char *module) {
    if (!so_path || !module) return 0;

    void *handle = dlopen(so_path, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) {
        if (perla_debug_mode()) {
            fprintf(stderr, "[xsloader] dlopen %s failed: %s\n", so_path, dlerror());
        }
        return 0;
    }

    char boot_name[512];
    build_boot_name(module, boot_name, sizeof(boot_name));

    void (*boot_fn)(void*) = (void (*)(void*))dlsym(handle, boot_name);
    if (!boot_fn) {
        if (perla_debug_mode()) {
            fprintf(stderr, "[xsloader] dlsym %s in %s failed: %s\n",
                    boot_name, so_path, dlerror());
        }
        return 0;
    }

    if (perla_debug_mode()) {
        fprintf(stderr, "[xsloader] %s: dlopened %s, calling %s\n",
                module, so_path, boot_name);
    }

    /* Call boot_Foo__Bar with an empty args frame. It registers XS subs
     * via newXS_deffile → perla_code_set. The boot's XSRETURN_YES (if
     * generated) pushes an immortal true SV which we pop+ignore. */
    long mark_idx = (long)(perla_sp - perla_stack);
    if ((perla_markstack_ptr - perla_markstack) + 1 < 255) {
        *++perla_markstack_ptr = (I32)mark_idx;
    }
    boot_fn(NULL);
    /* Discard any pushed returns */
    long new_top = (long)(perla_sp - perla_stack);
    for (long i = mark_idx + 1; i <= new_top; i++) {
        StradaValue *v = perla_stack[i];
        if (v && v != &perla_sv_yes_val && v != &perla_sv_no_val
              && v != &perla_sv_undef_val) {
            strada_decref(v);
        }
        perla_stack[i] = NULL;
    }
    perla_sp = perla_stack + mark_idx;
    if (perla_markstack_ptr > perla_markstack) perla_markstack_ptr--;

    return 1;
}

/* ============================================================
 * perla_xsloader_load / perla_dynaloader_bootstrap
 * ============================================================ */

/* Find auto/<relpath>/<basename>.so in @INC. Returns 0 on success
 * (fills out_path), 1 if not found. */
static int find_xs_so(const char *module, char *out_path, size_t out_sz) {
    perla_require_ensure_paths();

    /* Convert Foo::Bar → Foo/Bar (relpath) + Bar (basename) */
    size_t mlen = strlen(module);
    char rel[1024];
    size_t ri = 0;
    const char *basename = module;
    for (size_t i = 0; i < mlen && ri + 4 < sizeof(rel); i++) {
        if (module[i] == ':' && i + 1 < mlen && module[i + 1] == ':') {
            rel[ri++] = '/';
            i++;
            basename = module + i + 1;
        } else {
            rel[ri++] = module[i];
        }
    }
    rel[ri] = '\0';

    for (size_t i = 0; i < g_require_path_count; i++) {
        char candidate[2048];
        snprintf(candidate, sizeof(candidate), "%s/auto/%s/%s.so",
                 g_require_paths[i], rel, basename);
        struct stat st;
        if (stat(candidate, &st) == 0 && S_ISREG(st.st_mode)) {
            strncpy(out_path, candidate, out_sz - 1);
            out_path[out_sz - 1] = '\0';
            return 0;
        }
    }
    return 1;
}

StradaValue *perla_xsloader_load(StradaValue *args) {
    /* args is an array: (module_name, [version], [file]).
     * We ignore version + file; Perla doesn't version-gate XS loads. */
    StradaArray *av = NULL;
    if (args && !STRADA_IS_TAGGED_INT(args) && args->type == STRADA_ARRAY) {
        av = args->value.av;
    }
    if (!av || av->size < 1) {
        /* Modern XSLoader convention: `XSLoader::load()` with no args loads
         * the XS for the CALLER's package (XSLoader derives it from caller()).
         * perla used to die here, so any module using the no-arg form (a
         * common idiom, e.g. via `use XSLoader; XSLoader::load();`) aborted.
         * Walk the call stack for the nearest frame that isn't XSLoader /
         * DynaLoader and re-enter with that package name. */
        const char *cpkg = NULL;
        for (int i = perla_call_depth - 1; i >= 0; i--) {
            const char *p = perla_call_stack[i].package;
            if (p && p[0]
                && strcmp(p, "XSLoader") != 0
                && strcmp(p, "DynaLoader") != 0) {
                cpkg = p;
                break;
            }
        }
        if (cpkg) {
            StradaValue *fake = strada_new_array();
            strada_array_push_take(fake->value.av, strada_new_str(cpkg));
            StradaValue *r = perla_xsloader_load(fake);
            strada_decref(fake);
            return r;
        }
        strada_die("XSLoader::load requires a module name");
        return strada_new_undef();
    }

    StradaValue *mod_sv = strada_array_get(av, 0);
    char *module = mod_sv ? strada_to_str(mod_sv) : NULL;
    if (!module || !module[0]) {
        if (module) free(module);
        strada_die("XSLoader::load got empty module name");
        return strada_new_undef();
    }

    char so_path[2048];
    if (find_xs_so(module, so_path, sizeof(so_path)) != 0) {
        /* No XS .so on disk. If perla has native interception for this
         * module (e.g. DBI dispatched via perla_dbi_connect, even when
         * the DBI package stash is empty because DBI.pm wasn't loaded),
         * silently return success — the calls land on the native impl
         * via perla_method_dispatch. Without this, every fresh `use DBI;`
         * in a program that doesn't precompile DBI.pm.o dies at module
         * load with "can't locate auto/.../*.so for DBI in @INC". */
        if (strcmp(module, "DBI") == 0) {
            free(module);
            return STRADA_MAKE_TAGGED_INT(1);
        }
        /* Include "loadable object" in the error so callers that
         * conditionally catch XS-load failures (DateTime.pm's
         * `catch { die $_ if $_ && $_ !~ /object version|loadable object/ }`
         * pattern, JSON::Backend probes, IO::Socket::SSL fallbacks, etc.)
         * recognise the failure and fall through to their pure-Perl path.
         * Otherwise the catch block re-throws and the whole module init
         * aborts — DateTime never registers PP methods, every `DateTime->now`
         * dies with "Can't locate _ymd2rd / _time_as_seconds / etc." */
        char errmsg[512];
        snprintf(errmsg, sizeof(errmsg),
                 "Can't load loadable object for module %s: can't locate auto/.../*.so in @INC", module);
        free(module);
        strada_die("%s", errmsg);
        return strada_new_undef();
    }

    if (!perla_xs_bootstrap_so(so_path, module)) {
        /* If the package already has a populated stash (i.e. perla
         * registered a native C impl for it — DBI is the canonical
         * case, with perla_dbi_connect intercepting DBI->connect),
         * the XS bootstrap failure is non-fatal: the calls will land
         * on the native impl. Without this check, dying here at
         * try_depth=0 (the typical context for module init) silently
         * exits the program — DBI.pm's `XSLoader::load("DBI")` runs
         * during `use DBI`, and a fatal die there means anyone using
         * DBI never reaches the rest of their script. */
        /* "Native" lie-success: perla intercepts the module's calls via
         * method_dispatch hooks rather than the .pm-side dispatch.
         * For these modules, lying about XSLoader::load success keeps the
         * .pm.so init path alive so its perl-side helpers register, while
         * the actual XS-implemented methods land on perla's natives.
         *
         * Allowlist explicitly. A "stash has any STRADA_STR sub" check
         * would also include modules like DateTime whose .pm.so registered
         * its perl-compiled subs — but DateTime needs XSLoader::load to
         * FAIL so its `catch { require DateTime::PP }` fallback can run,
         * otherwise _ymd2rd / _time_as_seconds / etc. never register and
         * `DateTime->now` dies "Can't locate _ymd2rd". */
        int has_native = 0;
        {
            static const char *native_lie_modules[] = {
                "DBI",
                "DBD::mysql",
                "DBD::Pg",
                "DBD::SQLite",
                "Storable",
                "Data::Dumper",
                "List::MoreUtils::XS",
                "JSON::XS",
                "Cpanel::JSON::XS",
                /* List::Util is pure-XS (no .pm-side pure-Perl fallback), so a
                 * fatal XSLoader::load death during `use List::Util` would exit
                 * the program. perla registers the full List::Util API natively
                 * in the stash (first/reduce/sum/max/uniq/pairs/...), so lie
                 * success: the .pm.so finishes init (sets @EXPORT_OK/$VERSION),
                 * Exporter copies the native subs into the caller, and all calls
                 * land on perla's natives. */
                "List::Util",
                /* Fcntl is pure-XS (constants from C's fcntl.h). perla
                 * registers the O_xxx, SEEK_xxx, LOCK_xxx and S_xxx constants
                 * natively, so a fatal XSLoader death during `use Fcntl`
                 * (Fcntl.pm calls the no-arg `XSLoader::load()`) would abort
                 * the program. Lie success: the .pm finishes, Exporter copies
                 * the native constants. Hit loading DateTime's dep chain. */
                "Fcntl",
                /* POSIX is pure-XS; perla registers the commonly-used POSIX
                 * functions/constants natively (floor/ceil/strftime/setlocale/
                 * INT_MAX/...). Same rationale as Fcntl — `use POSIX` calls
                 * XSLoader and would die fatally otherwise. Lie success; calls
                 * land on perla's natives (unimplemented ones return undef
                 * rather than aborting the whole program). */
                "POSIX",
                /* More pure-XS core modules perla backs natively: B (perlstring
                 * /cstring/class/svref_2object), Cwd (getcwd/abs_path/...),
                 * Encode (encode/decode/...). `use`ing them calls XSLoader and
                 * would die fatally; lie success so the .pm finishes and calls
                 * land on perla's natives. (Time::HiRes/Hash::Util/Sub::Util are
                 * NOT listed — perla has no natives for them, so a clear failure
                 * beats silently-undef subs.) */
                "B",
                "Cwd",
                "Encode",
                /* Time::HiRes: gettimeofday/tv_interval/time/sleep/usleep are
                 * registered natively. */
                "Time::HiRes",
                /* Params::Util is pure-XS with NO pure-Perl fallback in its
                 * .pm (unconditional XSLoader::load). perla registers the full
                 * type-check API natively (_STRING/_INSTANCE/_CODELIKE/
                 * _HASHLIKE/_ARRAYLIKE/...), so a fatal XSLoader death during
                 * `use Params::Util` would abort the program. Lie success: the
                 * .pm.so finishes init, Exporter copies the native subs.
                 * Hit via Moose -> Class::Load -> Data::OptList. */
                "Params::Util",
                NULL,
            };
            for (int ni = 0; native_lie_modules[ni]; ni++) {
                if (strcmp(module, native_lie_modules[ni]) == 0) {
                    has_native = 1;
                    break;
                }
            }
        }
        if (has_native) {
            fprintf(stderr,
                    "XSLoader: bootstrap failed for %s — using perla's native impl\n",
                    module);
            free(module);
            return STRADA_MAKE_TAGGED_INT(1);
        }
        /* Use Perl's standard "loadable object" wording so callers that
         * conditionally catch XS-load failures (DateTime.pm's
         * /object version|loadable object/ regex, JSON::Backend probes,
         * IO::Socket::SSL fallbacks, etc.) can recognise the failure and
         * fall through to their pure-Perl path. */
        char errmsg[512];
        snprintf(errmsg, sizeof(errmsg),
                 "XSLoader: can't load loadable object for module %s: bootstrap failed (%s)",
                 module, so_path);
        free(module);
        strada_die("%s", errmsg);
        return strada_new_undef();
    }

    free(module);
    /* Return true (Perl convention) */
    return STRADA_MAKE_TAGGED_INT(1);
}

StradaValue *perla_dynaloader_bootstrap(StradaValue *args) {
    /* Older DynaLoader API — same mechanics */
    return perla_xsloader_load(args);
}

/* ============================================================
 * perla_xsloader_register — called from perla_init
 * ============================================================ */

void perla_xsloader_register(void) {
    /* Initialize immortal SVs: they need distinguishing types so
     * SvTRUE / SvIV do the right thing. PL_sv_yes is "1", PL_sv_no is "",
     * PL_sv_undef is undef. */
    perla_sv_yes_val.type = STRADA_INT;
    perla_sv_yes_val.value.iv = 1;
    perla_sv_yes_val.refcount = 10000;  /* effectively immortal */
    perla_sv_no_val.type = STRADA_INT;
    perla_sv_no_val.value.iv = 0;
    perla_sv_no_val.refcount = 10000;
    perla_sv_undef_val.type = STRADA_UNDEF;
    perla_sv_undef_val.refcount = 10000;

    /* Register XSLoader::load + DynaLoader::bootstrap as native C fns.
     * The %INC seeding (to stub `use XSLoader` / `use DynaLoader`) is
     * done in perla_init directly since g_INC_hash is static there.
     *
     * Use the *protected* registration so a later require of XSLoader.pm
     * (which defines its own perl-side `sub load`) doesn't override our
     * native impl. The .pm version's `dl_load_file` call goes nowhere
     * (perla has no DynaLoader XSubs) and falls through to a Carp::croak
     * with "Can't load '/auto/Foo/Foo.so' for module Foo: dl_error" — a
     * message that doesn't match callers' `loadable object` filters and
     * thus escapes their try blocks fatally. The native impl emits the
     * Perl-standard wording so DateTime/DBI/Data::Dumper/etc. can fall
     * through to their pure-perl path correctly. */
    perla_code_set_protected("XSLoader", "load",
                   strada_cpointer_new((void*)perla_xsloader_load));
    perla_code_set_protected("DynaLoader", "bootstrap",
                   strada_cpointer_new((void*)perla_dynaloader_bootstrap));
}
