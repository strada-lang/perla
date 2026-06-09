/*
 * perla_tcc_inlines.c - Export inline functions as real symbols for TCC
 *
 * These functions are static inline in strada_runtime.h. TCC needs real
 * linkable symbols. We provide them by calling the _impl versions or
 * reimplementing the simple ones.
 */

/* Minimal type declarations - just enough to compile these wrappers */
#include <stdint.h>
#include <stddef.h>

/* Forward declarations from strada_runtime.h */
typedef struct StradaValue StradaValue;
typedef struct StradaHash StradaHash;

/* Tagged integer check */
#define STRADA_IS_TAGGED_INT(sv) ((intptr_t)(sv) & 1)

/* Type enum values we need */
#define STRADA_HASH 6
#define STRADA_REF 7

/* Extern access to runtime internals */
#define STRADA_MAX_PENDING_CLEANUP 256
extern StradaValue *strada_pending_cleanup[STRADA_MAX_PENDING_CLEANUP];
extern int strada_pending_cleanup_count;

/* Functions from strada_runtime.c we can call */
extern void strada_incref_impl(StradaValue *sv);
extern void strada_decref_impl(StradaValue *sv);
extern StradaValue* strada_new_undef(void);
extern StradaValue* strada_hash_get(StradaHash *hash, const char *key);
extern void strada_hash_set(StradaHash *hash, const char *key, StradaValue *val);
extern int strada_hash_exists(StradaHash *hash, const char *key);
extern void strada_hash_delete(StradaHash *hash, const char *key);

/* Access StradaValue fields - we need the struct layout */
/* This must match strada_runtime.h exactly */
typedef unsigned int StradaType;
typedef union {
    int64_t iv;
    double nv;
    char *pv;
    StradaValue *rv;
    StradaHash *hv;
    void *ptr;
} StradaValueUnion;

typedef struct StradaMeta {
    char *blessed_package;
    char *struct_name;
} StradaMeta;

/* The actual StradaValue struct */
struct StradaValue {
    StradaType type;
    StradaValueUnion value;
    int refcount;
    StradaMeta *meta;
};

/* ===== Cleanup stack ===== */
void strada_cleanup_push(StradaValue *sv) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (strada_pending_cleanup_count < STRADA_MAX_PENDING_CLEANUP) {
        strada_pending_cleanup[strada_pending_cleanup_count++] = sv;
    }
}

void strada_cleanup_pop(void) {
    if (strada_pending_cleanup_count > 0) strada_pending_cleanup_count--;
}

/* ===== Hash inline wrappers ===== */
StradaValue* strada_hv_fetch(StradaValue *sv, const char *key) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return NULL;
    /* Auto-deref: if sv is a REF to a HASH, access through the ref */
    if (sv->type == STRADA_REF && sv->value.rv && sv->value.rv->type == STRADA_HASH) {
        sv = sv->value.rv;
    }
    if (sv->type != STRADA_HASH || !sv->value.hv) return NULL;
    return strada_hash_get(sv->value.hv, key);
}

StradaValue* strada_hv_fetch_owned(StradaValue *sv, const char *key) {
    StradaValue *v = strada_hv_fetch(sv, key);
    if (v) strada_incref_impl(v);
    return v ? v : strada_new_undef();
}

void strada_hv_store(StradaValue *sv, const char *key, StradaValue *val) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_REF && sv->value.rv && sv->value.rv->type == STRADA_HASH) sv = sv->value.rv;
    if (sv->type == STRADA_HASH) {
        if (!sv->value.hv) {
            sv->value.hv = strada_hash_new(16);
        }
        strada_hash_set(sv->value.hv, key, val);
    }
}

/* _take variant: caller donates ownership of val (no extra incref) */
void strada_hv_store_take(StradaValue *sv, const char *key, StradaValue *val) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_REF && sv->value.rv && sv->value.rv->type == STRADA_HASH) sv = sv->value.rv;
    if (sv->type == STRADA_HASH) {
        if (!sv->value.hv) {
            sv->value.hv = strada_hash_new(16);
        }
        strada_hash_set_take(sv->value.hv, key, val);
    }
}

int strada_hv_exists(StradaValue *sv, const char *key) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return 0;
    if (sv->type == STRADA_REF && sv->value.rv && sv->value.rv->type == STRADA_HASH) sv = sv->value.rv;
    if (sv->type != STRADA_HASH || !sv->value.hv) return 0;
    return strada_hash_exists(sv->value.hv, key);
}

void strada_hv_delete(StradaValue *sv, const char *key) {
    if (!sv || STRADA_IS_TAGGED_INT(sv) || sv->type != STRADA_HASH || !sv->value.hv) return;
    strada_hash_delete(sv->value.hv, key);
}

/* Call stack for caller() */
typedef struct {
    const char *package;
    const char *subname;
    const char *file;
    int line;
} PerlaCallFrame;
#define PERLA_CALL_STACK_SIZE 256
extern PerlaCallFrame perla_call_stack[PERLA_CALL_STACK_SIZE];
extern int perla_call_depth;

extern int perla_pending_call_line;

void perla_call_push(const char *pkg, const char *sub, const char *file, int line) {
    if (perla_call_depth < PERLA_CALL_STACK_SIZE) {
        perla_call_stack[perla_call_depth].package = pkg;
        perla_call_stack[perla_call_depth].subname = sub;
        perla_call_stack[perla_call_depth].file = file;
        /* Prefer pending_call_line set by the caller at the call site
         * (carries the call's source line). Fall back to the literal
         * `line` param if not set. Reset after consume so subsequent
         * pushes without a fresh set don't inherit stale value. */
        perla_call_stack[perla_call_depth].line = perla_pending_call_line ? perla_pending_call_line : line;
        perla_pending_call_line = 0;
        perla_call_depth++;
    }
}

void perla_call_pop(void) {
    if (perla_call_depth > 0) perla_call_depth--;
}

int strada_is_slot_ref(StradaValue *sv) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return 0;
    return (sv->type == STRADA_REF && sv->value.rv != NULL) ? 1 : 0;
}

/* ---- libgcc soft-float helpers for the tcc backend ------------------------
 * gcc inlines 64-bit integer <-> floating conversions on x86-64, so x86-64
 * libgcc does NOT ship these symbols — but tcc emits calls to them (e.g.
 * __floatundidf for an unsigned-64 -> double in tagged-int math). Provide
 * them here so the tcc-compiled object links (pulled from perla_runtime_tcc.a
 * only when referenced). All are exact-cast trivial. */
double   __floatdidf(int64_t x)   { return (double)x; }
double   __floatundidf(uint64_t x){ return (double)x; }
float    __floatdisf(int64_t x)   { return (float)x; }
float    __floatundisf(uint64_t x){ return (float)x; }
int64_t  __fixdfdi(double x)      { return (int64_t)x; }
uint64_t __fixunsdfdi(double x)   { return (uint64_t)x; }
int64_t  __fixsfdi(float x)       { return (int64_t)x; }
uint64_t __fixunssfdi(float x)    { return (uint64_t)x; }
