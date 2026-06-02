/*
 * perla_xsloader.h — Runtime XSLoader / DynaLoader bootstrap for Perla
 *
 * When a CPAN XS module is loaded at runtime, its .pm file typically
 * does `use XSLoader; XSLoader::load('Foo::Bar')`. In stock Perl this
 * dlopens auto/Foo/Bar/Bar.so and calls boot_Foo__Bar, which in turn
 * calls newXS_deffile for each XS sub in the module.
 *
 * This header declares the Perla-side equivalents so XS modules
 * installed by perla-cpan actually load at runtime.
 *
 * Design notes:
 *
 * - XS sub calling convention is `void fn(CV *cv)` — args come from
 *   perla_stack between the mark and sp; return values are pushed
 *   back onto perla_stack. This is different from Perla's native
 *   `StradaValue *(*)(StradaValue *args)` convention.
 *
 * - XS subs are stored in the stash as STRADA_CPOINTER values tagged
 *   with struct_name="XSUB". perla_call_code detects this marker and
 *   routes through perla_xs_invoke (this file) instead of calling the
 *   C function pointer directly with Perla-style args.
 *
 * - The stack globals themselves (perla_stack, perla_sp, etc.) are
 *   declared extern in perla_perl_compat.h. This file defines the
 *   storage (via #define PERLA_XS_STATE_OWNER). That way the XS .so
 *   (which also includes perla_perl_compat.h) sees externs that
 *   resolve to the main Perla binary's single instance at dlopen time.
 *   RTLD_GLOBAL + -rdynamic make this work.
 */

#ifndef PERLA_XSLOADER_H
#define PERLA_XSLOADER_H

#include "strada_runtime.h"

/* Create a STRADA_CPOINTER with struct_name="XSUB" so perla_call_code
 * knows to dispatch through the XS calling-convention bridge. */
StradaValue *perla_xsub_new(void (*xs_fn)(void*));

/* Return 1 if `sv` is an XSUB-marked CPOINTER. */
int perla_is_xsub(StradaValue *sv);

/* Invoke an XS function with Perla-style args, returning the value(s)
 * pushed onto perla_stack: undef for 0 returns, scalar for 1, array
 * reference for >1. The XS function `xs_fn` must use the standard XS
 * calling convention (void fn(CV*); args in perla_stack between mark
 * and sp; returns pushed onto perla_stack).
 *
 * Not named `perla_xs_invoke` — that collides with a static inline in
 * perla_perl_compat.h (the call_sv/call_method helper). */
StradaValue *perla_xsub_invoke(void (*xs_fn)(void*), StradaValue *args);

/* Dlopen `so_path` and call `boot_<module_underscored>`. Used by both
 * the require-time XS bootstrap (perla_stash.c) and the explicit
 * XSLoader::load / DynaLoader::bootstrap calls. Returns 1 on success,
 * 0 on failure. */
int perla_xs_bootstrap_so(const char *so_path, const char *module);

/* XSLoader::load(module, [version, [file]]) — stash callable.
 * Dispatched by perla_call_code when a .pm does `XSLoader::load(...)`. */
StradaValue *perla_xsloader_load(StradaValue *args);

/* DynaLoader::bootstrap(module) — same mechanics, older Perl API. */
StradaValue *perla_dynaloader_bootstrap(StradaValue *args);

/* Register XSLoader::load and DynaLoader::bootstrap in the stash,
 * and seed XSLoader.pm / DynaLoader.pm in %INC so `use XSLoader` is a
 * no-op. Called once from perla_init. */
void perla_xsloader_register(void);

#endif /* PERLA_XSLOADER_H */
