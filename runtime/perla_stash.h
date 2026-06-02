/*
 * perla_stash.h - Perl 5 Symbol Table (Stash) Runtime
 *
 * Implements Perl's package-based symbol table with typeglob semantics.
 * Each package has a "stash" (symbol table hash) mapping names to globs.
 * Each glob can simultaneously hold a scalar, array, hash, code ref,
 * and IO handle — the core of Perl's type system.
 *
 * This is linked into every compiled Perla program alongside strada_runtime.
 */
#ifndef PERLA_STASH_H
#define PERLA_STASH_H

#include "strada_runtime.h"

/* Binary-safe string-literal constructor — uses sizeof on the literal so
 * embedded NUL bytes ("\x00""ABC", \0 mid-string) survive instead of being
 * truncated by strada_new_str's implicit strlen. The argument must be a real
 * C string literal (the C compiler computes sizeof at translation time). */
#define PERLA_NEW_STR_LIT(LIT) strada_new_str_len((LIT), sizeof(LIT) - 1)
/* UTF-8 char-oriented variant — sets SVf_UTF8 so length()/uc()/etc.
 * count code points. Source must be valid UTF-8 bytes. */
#define PERLA_NEW_STR_LIT_UTF8(LIT) strada_new_str_len_utf8((LIT), sizeof(LIT) - 1)

/* ===== Glob Slots ===== */
#define PERLA_SLOT_SCALAR  0
#define PERLA_SLOT_ARRAY   1
#define PERLA_SLOT_HASH    2
#define PERLA_SLOT_CODE    3
#define PERLA_SLOT_IO      4
#define PERLA_SLOT_FORMAT  5
#define PERLA_SLOT_COUNT   6

/* ===== Typeglob ===== */
typedef struct PerlGlob {
    StradaValue *slots[PERLA_SLOT_COUNT];  /* Typed slots */
    char *name;                             /* Short name (e.g., "foo") */
    char *fullname;                         /* Fully qualified (e.g., "main::foo") */
    /* Bitmask of slot indices whose value is a "frozen" native override
     * (set by perla_code_set_protected). User-perl `sub` definitions
     * compile to a perla_code_set() call that would otherwise replace
     * the pointer with a STRADA_STR holding the C function name —
     * which then fails to dispatch correctly because the C symbol
     * doesn't match a real method name. */
    int frozen_slots;
    /* Write-aliasing for `*Target = \$Source::var`. alias_to_slot is
     * the address of the source's SCALAR slot — set when this glob
     * was made an alias. aliased_by lists every glob that aliases
     * INTO this glob's SCALAR slot — set on the source side so a
     * write to source propagates to every aliased target glob, and
     * vice versa (writes to target route through alias_to_slot to
     * source, which then fan out to aliased_by). */
    StradaValue **alias_to_slot;
    struct PerlGlob **aliased_by;
    size_t aliased_by_count;
    size_t aliased_by_capacity;
} PerlGlob;

/* ===== Package Stash ===== */
typedef struct PerlStash {
    char *name;             /* Package name (e.g., "main") */
    PerlGlob **entries;     /* Glob table */
    char **keys;            /* Parallel key array */
    int count;
    int capacity;
    StradaValue *isa;       /* @ISA array (StradaValue of type ARRAY) */
    /* Set by perla_mod_init_X — module's source was inlined at compile
     * time, so a runtime `require` can skip the dlopen+compile path.
     * NOT set by ad-hoc perla_code_set() calls (e.g., native-override
     * pre-seeding at perla_init), since those don't represent a fully
     * loaded module — they just install a few overriding subs and the
     * rest of the .pm still needs to load. */
    int is_inlined;
    /* MRO algorithm for this package: 0 = DFS (Perl default), 1 = C3.
     * Set by `use mro 'c3'` in the package's compilation. Consulted by
     * perla_method_resolve to walk @ISA in the configured order. */
    int mro_c3;
} PerlStash;

/* ===== Save Stack (for local/dynamic scoping) ===== */
typedef struct PerlSaveEntry {
    PerlGlob *glob;
    int slot;
    StradaValue *saved_value;
} PerlSaveEntry;

/* ===== Boolean (Perl-compatible: refs always truthy) ===== */
int perla_to_bool(StradaValue *sv);

/* Mark a stash as fully inlined — set by perla_mod_init_X so a runtime
 * `require` short-circuits past the compile+dlopen path. */
void perla_stash_mark_inlined(const char *pkg);

/* Like perla_code_set, but freezes the CODE slot so subsequent
 * perla_code_set calls with a STRADA_STR (the user-perl `sub`
 * registration form) don't replace the native override. */
void perla_code_set_protected(const char *pkg, const char *name, StradaValue *val);

/* Sub::Util::set_prototype($proto, $coderef) — emitted directly by
 * codegen so declaration must be public. Attaches prototype string
 * (or clears via undef) and returns the coderef. */
StradaValue *perla_sub_util_set_prototype(StradaValue *args);

/* Direct (non-array) variant called inline from codegen — mutates
 * $coderef SV in place to attach the prototype string. */
void perla_sub_util_set_prototype_direct(StradaValue *proto_sv, StradaValue *cv);

/* ===== Initialization ===== */
void perla_init(void);
void perla_cleanup(void);

/* ===== Stash (Package) Management ===== */
PerlStash *perla_stash_get(const char *pkg);
PerlStash *perla_stash_get_or_create(const char *pkg);
int perla_stash_exists(const char *pkg);

/* Snapshot of `%Pkg::` as a fresh StradaValue HASH: each key is a
 * defined glob's name; each value is the string "*Pkg::name" matching
 * Perl's stash-as-hash semantics. Used by codegen for `keys %Pkg::`,
 * `each %Pkg::`, etc. Snapshot, not live — mutations to the returned
 * hash don't affect the underlying stash. */
StradaValue *perla_stash_as_hash(const char *pkg);

/* ===== Glob Management ===== */
PerlGlob *perla_glob_get(PerlStash *stash, const char *name);
PerlGlob *perla_glob_get_or_create(PerlStash *stash, const char *name);
PerlGlob *perla_glob_lookup(const char *fullname);  /* "Pkg::name" lookup */

/* ===== Glob Slot Access ===== */
StradaValue *perla_glob_fetch(PerlGlob *glob, int slot);
void perla_glob_store(PerlGlob *glob, int slot, StradaValue *val);

/* Convenience accessors */
StradaValue *perla_scalar_get(const char *pkg, const char *name);
StradaValue **perla_scalar_lvalue(const char *pkg, const char *name);
void perla_hash_clear(StradaValue *hv_sv);
void perla_array_clear(StradaValue *av_sv);
void perla_scalar_set(const char *pkg, const char *name, StradaValue *val);
StradaValue *perla_array_get(const char *pkg, const char *name);
StradaValue *perla_scalar_via_qname(const char *qname);
void perla_scalar_set_via_qname(const char *qname, StradaValue *val);
StradaValue *perla_array_via_qname(const char *qname);
StradaValue *perla_hash_via_qname(const char *qname);
void perla_array_set(const char *pkg, const char *name, StradaValue *val);
StradaValue *perla_hash_get(const char *pkg, const char *name);
void perla_hash_set(const char *pkg, const char *name, StradaValue *val);
StradaValue *perla_code_get(const char *pkg, const char *name);
StradaValue *perla_code_get_walking(const char *name);
void perla_register_imported(const char *pkg);
void perla_code_set(const char *pkg, const char *name, StradaValue *val);
StradaValue *perla_call_code(StradaValue *code_val, StradaValue *args);
/* Install a Perl-style signal handler.
 *   name:    signal name without "SIG" prefix ("USR1", "INT", "TERM", ...)
 *   handler: STRADA_CLOSURE / STRADA_CODE / STRADA_REF coderef, or a
 *            STRADA_STR with "IGNORE" / "DEFAULT" / "" (== DEFAULT).
 * Called when `$SIG{NAME} = ...` is assigned. */
void perla_install_signal(const char *name, StradaValue *handler);

/* Byte-wise string bitwise ops. Return NULL if either arg isn't
 * STRADA_STR — caller should fall back to the numeric path. */
StradaValue *perla_str_or(StradaValue *a, StradaValue *b);
StradaValue *perla_str_and(StradaValue *a, StradaValue *b);
StradaValue *perla_str_xor(StradaValue *a, StradaValue *b);

/* CPOINTER stub used as the target of `\&undefined_sub`. ref() returns
 * "CODE"; calling it dies "Undefined subroutine called". */
StradaValue *perla_undef_coderef(void);
StradaValue *perla_undef_coderef_named(const char *name);

void perla_mark_loaded(const char *module);
void perla_set_mro(const char *pkg, const char *algo);
int  perla_try_require(const char *module);
int  perla_try_load_precompiled(const char *module);
void perla_init_moose_stubs(void);
void perla_moose_xs_boot(void);
StradaValue *perla_moose_import(StradaValue *args);
StradaValue *perla_moose_role_import(StradaValue *args);
StradaValue *perla_mop_hash_accessor_name(StradaValue *args);
StradaValue *perla_mop_process_accessors(StradaValue *args);
StradaValue *perla_mop_get_all_attributes(StradaValue *args);
StradaValue *perla_throw_exception(StradaValue *args);

/* ===== Typeglob Assignment (*foo = \$bar, *foo = \&func, etc.) ===== */
void perla_glob_assign(PerlGlob *glob, StradaValue *val);
void perla_glob_alias(const char *dst_pkg, const char *dst_name,
                      const char *src_pkg, const char *src_name);

/* ===== Dynamic Scoping (local) ===== */
int perla_save_mark(void);                          /* Get current save stack position */
void perla_save_slot(PerlGlob *glob, int slot);     /* Push current value onto save stack */
void perla_save_scalar(const char *pkg, const char *name);
void perla_save_array(const char *pkg, const char *name);
void perla_save_hash(const char *pkg, const char *name);
void perla_restore(int mark);                       /* Restore all saves back to mark */

/* ===== Method Resolution ===== */
PerlGlob *perla_method_resolve(const char *pkg, const char *method);
PerlGlob *perla_autoload_resolve(const char *pkg);
StradaValue *perla_method_lookup(const char *pkg, const char *method);
StradaValue *perla_get_autoload_var(void);
void perla_set_autoload_var_sv(StradaValue *val);
StradaValue *perla_try_autoload(const char *pkg, const char *method,
                                 StradaValue *obj, StradaValue *args);
StradaValue *perla_method_dispatch(StradaValue *obj, const char *method, StradaValue *args);
StradaValue *perla_exporter_import_pub(StradaValue *args);  /* promote requested names from a no-import module's stash into the caller */

/* ===== @ISA Management ===== */
StradaValue *perla_isa_get(const char *pkg);
void perla_isa_push(const char *pkg, const char *parent);
void perla_isa_reset(const char *pkg);
int perla_isa_check(const char *pkg, const char *target);

/* ===== Introspection ===== */
StradaValue *perla_stash_keys(const char *pkg);     /* keys %Pkg:: */
int perla_can(const char *pkg, const char *method);
StradaValue *perla_can_code(const char *pkg, const char *method);
/* blessed($ref) — hot on every method dispatch, so inline it (trivial: read the
 * blessed_package off the meta). Avoids an out-of-line call per `$obj->meth()`. */
static inline const char *perla_blessed(StradaValue *ref) {
    if (!ref || STRADA_IS_TAGGED_INT(ref)) return NULL;
    if (ref->meta && ref->meta->blessed_package) return ref->meta->blessed_package;
    return NULL;
}
StradaValue *perla_bless(StradaValue *ref, const char *pkg);
StradaValue *perla_fh_slot_get(StradaValue *gv);      /* ${*$fh} read */
StradaValue *perla_fh_slot_set(StradaValue *gv, StradaValue *v); /* ${*$fh} = v */
char *perla_class_name(StradaValue *sv);              /* class name for bless — honors blessed_package */

/* ===== Global-destruction DESTROY sweep =====
 * Perl fires DESTROY for every still-blessed object at end of program even
 * if its refcount > 0. perla mirrors that here: perla_bless registers the
 * ref; perla_destroy_sweep (called from perla_cleanup) walks the registry
 * and invokes DESTROY for any entries whose meta + blessed_package are
 * still set (i.e. the obj wasn't freed via the normal rc=0 path, which
 * already fired DESTROY and cleared blessed_package).
 *
 * perla_in_global_destruction_active returns 1 while the sweep is running
 * — Devel::GlobalDestruction::in_global_destruction reads this. */
void perla_blessed_registry_add(StradaValue *ref);
void perla_blessed_registry_remove(StradaValue *ref);
void perla_destroy_sweep(void);
int perla_in_global_destruction_active(void);

/* ===== Method Dispatch ===== */
StradaValue *perla_method_dispatch(StradaValue *obj, const char *method, StradaValue *args);
StradaValue *perla_super_dispatch(StradaValue *obj, const char *current_pkg, const char *method, StradaValue *args);
StradaValue *perla_next_method_dispatch(StradaValue *obj, StradaValue *args, int maybe);

/* ===== Scalar tie ===== */
/* tie $scalar, 'Class', @args — calls Class->TIESCALAR via perla's
 * dispatch (so user-defined subs are visible), attaches the tied object
 * to target->meta. Reads through this scalar dispatch FETCH via the
 * strada_to_int/str/num/bool checks. Returns the tied object (incref'd
 * for the caller; the meta also holds its own reference). */
StradaValue *perla_tie_scalar(StradaValue *target, const char *classname, int argc, ...);

/* untie $scalar — call UNTIE if defined, release the tied object,
 * clear is_tied. No-op on untied SVs. */
void perla_untie_scalar(StradaValue *target);

/* ===== Custom Sort ===== */
typedef StradaValue* (*perla_cmp_func)(StradaValue *args);
StradaValue* perla_sort_custom(StradaValue *arr, void *cmp_fn);
StradaValue* perla_sort_native(StradaValue *arr, int mode);

/* ===== Special Variables ===== */
void perla_init_special_vars(void);
StradaValue *perla_special_get(const char *name);    /* $!, $@, $_, $/, etc. */
void perla_special_set(const char *name, StradaValue *val);

/* $/-aware chomp. Caller takes ownership of the returned char* (free). */
char *perla_chomp_irs(const char *str);

/* ===== File test stat cache (Perl's `_` token) =====
 * `-e $f; -f _` shares the previous stat. We don't share the stat struct
 * (too many code paths); instead, remember the last file-test path and
 * re-run the syscall when `_` is referenced. Small perf cost; correct
 * semantics. YAML::Tiny / File::Spec / many CPAN modules rely on this. */
extern char perla_last_stat_path[4096];
void perla_remember_stat_path(const char *path);

/* ===== Call Stack (for caller()) ===== */
#define PERLA_CALL_STACK_SIZE 256
typedef struct {
    const char *package;
    const char *subname;
    const char *file;
    int line;
} PerlaCallFrame;

extern PerlaCallFrame perla_call_stack[PERLA_CALL_STACK_SIZE];
extern int perla_call_depth;

extern int perla_pending_call_line;

/* True call depth (not capped at PERLA_CALL_STACK_SIZE like
 * perla_call_depth). Used to emit Perl's "Deep recursion" warning at
 * 100 frames. perla_call_depth freezes at 256 because it indexes a
 * fixed array for caller(); this counter is only for the warning. */
extern int perla_real_call_depth;
/* perl's "Deep recursion on …" warning is in the `recursion` warnings
 * category which is OFF by default — only `use warnings` enables it.
 * perla doesn't track lexical-pragma `use warnings 'recursion'` at the
 * call site, so emitting unconditionally surprised users with warnings
 * they wouldn't see in perl. Default to OFF; let the env var
 * PERLA_WARN_RECURSION=1 (or any non-empty value) opt in for those who
 * actually want it. */
#define PERLA_RECURSION_WARN_DEPTH 100

extern int perla_warn_recursion_enabled;
void perla_emit_deep_recursion_warning(const char *pkg, const char *sub, const char *file, int line);

/* Smartmatch `~~` — common-case Perl smartmatch semantics. Returns
 * STRADA_MAKE_TAGGED_INT(1) when matched, strada_new_str("") when not
 * (perl's true=1 / false="" convention for comparison ops). Handles:
 *   RHS undef  → !defined(LHS)
 *   RHS array  → grep equality (string or numeric depending on LHS type)
 *   RHS hash   → exists($rhs->{LHS-as-key})
 *   RHS regex  → LHS =~ regex
 *   RHS code   → $rhs->(LHS) coerced to bool
 *   fallback   → LHS eq RHS (stringy) */
StradaValue *perla_smartmatch(StradaValue *lhs, StradaValue *rhs);

/* Thread-local subname override consumed by the next perla_call_push.
 * Set by perla_call_code right before invoking a code value when the
 * SV has a Sub::Util::set_subname-attached name. Without this hook,
 * caller(0)[3] inside the called sub returned perla's internal
 * __perla_anon_N placeholder rather than the user-attached name. */
extern __thread const char *perla_pending_subname_override;
extern __thread const char *perla_pending_package_override;

static inline void perla_call_push(const char *pkg, const char *sub, const char *file, int line) {
    perla_real_call_depth++;
    if (perla_warn_recursion_enabled < 0) {
        const char *e = getenv("PERLA_WARN_RECURSION");
        perla_warn_recursion_enabled = (e && e[0]) ? 1 : 0;
    }
    if (perla_warn_recursion_enabled && perla_real_call_depth == PERLA_RECURSION_WARN_DEPTH) {
        perla_emit_deep_recursion_warning(pkg, sub, file,
            perla_pending_call_line ? perla_pending_call_line : line);
    }
    if (perla_call_depth < PERLA_CALL_STACK_SIZE) {
        const char *eff_pkg = pkg;
        const char *eff_sub = sub;
        if (perla_pending_subname_override) {
            const char *fq = perla_pending_subname_override;
            const char *sep = strstr(fq, "::");
            if (sep) {
                /* "Pkg::name" → split — copy into call frame's static
                 * scratch strings. Simplest: leak strdup; the frame's
                 * lifetime is bounded by the function call so this is
                 * negligible. */
                size_t plen = (size_t)(sep - fq);
                static __thread char pkgbuf[256], subbuf[256];
                if (plen >= sizeof(pkgbuf)) plen = sizeof(pkgbuf) - 1;
                memcpy(pkgbuf, fq, plen); pkgbuf[plen] = 0;
                const char *sub_part = sep + 2;
                size_t slen = strlen(sub_part);
                if (slen >= sizeof(subbuf)) slen = sizeof(subbuf) - 1;
                memcpy(subbuf, sub_part, slen); subbuf[slen] = 0;
                eff_pkg = pkgbuf;
                eff_sub = subbuf;
            } else {
                eff_sub = fq;
            }
            perla_pending_subname_override = NULL;
        }
        if (perla_pending_package_override) {
            eff_pkg = perla_pending_package_override;
            perla_pending_package_override = NULL;
        }
        perla_call_stack[perla_call_depth].package = eff_pkg;
        perla_call_stack[perla_call_depth].subname = eff_sub;
        perla_call_stack[perla_call_depth].file = file;
        /* Prefer the call-site line (set by codegen via
         * perla_pending_call_line just before the call) over the
         * literal `line` argument (which is 0 from the function-entry
         * push). Reset after consume so a follow-on call without a
         * fresh set doesn't inherit a stale line. */
        perla_call_stack[perla_call_depth].line = perla_pending_call_line ? perla_pending_call_line : line;
        perla_pending_call_line = 0;
        perla_call_depth++;
    }
}

static inline void perla_call_pop(void) {
    if (perla_real_call_depth > 0) perla_real_call_depth--;
    if (perla_call_depth > 0) perla_call_depth--;
}

StradaValue *perla_caller(int level);

/* ===== Runtime require ===== */
StradaValue *perla_require_module(StradaValue *module_sv);

/* ===== Data::Dumper ===== */
StradaValue *perla_dumper(StradaValue *args);

/* ===== Dynamic Glob Assignment ===== */
StradaValue *perla_glob_assign_dynamic(StradaValue *name_sv, StradaValue *val);
StradaValue *perla_glob_assign_dynamic_pkg(StradaValue *name_sv, StradaValue *val, const char *default_pkg);

/* ===== eval STRING ===== */
void perla_eval_set_paths(const char *perla_path, const char *strada_dir);
StradaValue *perla_eval_string(StradaValue *code_sv, const char *current_pkg);
StradaValue *perla_eval_string_with_args(StradaValue *code_sv, const char *current_pkg, StradaValue *caller_args);
StradaValue *perla_eval_string_with_lexicals(StradaValue *code_sv, const char *current_pkg, StradaValue *caller_args, StradaValue *caps);
StradaValue *perla_get_eval_caps(StradaValue *args);

/* sysopen($fh, $path, $flags, $perms) — POSIX open(2) with explicit flags
 * (Fcntl O_*), then fdopen to a STRADA_FILEHANDLE. Returns the handle on
 * success or undef on failure (caller reads $! for errno). */
StradaValue *perla_sysopen(StradaValue *path_sv, int64_t flags, int64_t perms);

/* ===== local on hash element =====
 * Per-call chain pointer in __perla_local_chain holds save records.
 * push_hash_elem installs the new value and pushes a save; restore_all
 * walks the chain at function exit and reverses every install. */
void *perla_local_push_hash_elem(void *chain, StradaValue *hashref,
                                 StradaValue *key_sv, StradaValue *new_val);
void *perla_local_push_array_elem(void *chain, StradaValue *arrayref,
                                  int idx, StradaValue *new_val);
void *perla_local_push_scalar_slot(void *chain, StradaValue **slot,
                                   StradaValue *new_val);
void *perla_local_push_scalar_slot_m(void *chain, StradaValue **slot,
                                     StradaValue *new_val,
                                     StradaValue **mirror);
void perla_local_chain_restore_all(void *chain);
void perla_local_chain_restore_to(void *chain, void *marker);
extern void *__perla_local_chain;

/* each @arr — perla-side state table (strada doesn't track array iters) */
StradaValue *perla_array_each(StradaArray *av);

/* IO::Compress::Gzip / IO::Uncompress::Gunzip (zlib). src/dst each a scalar-ref
 * (in-memory) or a filename string. Return tagged-int 1 / "" (false). */
StradaValue *perla_io_gzip(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_gunzip(StradaValue *src, StradaValue *dst);
/* IO::Compress::Deflate/Inflate (zlib), RawDeflate/RawInflate (raw), and
 * Bzip2/Bunzip2 (libbz2). Same ($src => $dst) scalar-ref/filename contract. */
StradaValue *perla_io_deflate(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_inflate(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_rawdeflate(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_rawinflate(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_bzip2(StradaValue *src, StradaValue *dst);
StradaValue *perla_io_bunzip2(StradaValue *src, StradaValue *dst);
void perla_compress_zlib_register(void);

/* use bigint — arbitrary-precision integer arithmetic. op is + - * ** or a
 * comparison (< > <= >= == != <=>). Returns a tagged int (fits int64) or a
 * decimal-string STR carrying the big value. */
StradaValue *perla_bigint_binop(const char *op, StradaValue *a, StradaValue *b);

/* caller() line tracking — codegen sets at each call site; perla_call_push
 * consumes into the new frame's `line` field. */
extern int perla_pending_call_line;

#endif /* PERLA_STASH_H */
