/*
 * perla_perl_runtime.c — Core Perl runtime for XS module support
 *
 * Implements the key Perl API functions that DBI actually USES:
 *   - XS function registration (newXS) and dispatch (call_sv/call_method)
 *   - SV Magic (for DBI handle tracking)
 *   - Stash/GV (for method resolution)
 *   - Perl stack operations
 *
 * This replaces the stub implementations in perla_perl_api.c
 * for the functions that DBI critically needs.
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
/* Internal hash/array body types for our HV/AV implementation */
typedef struct perla_he {
    char *key;
    SV *val;
    struct perla_he *next;
} PerlaHE;

typedef struct {
    PerlaHE **buckets;
    int num_buckets;
    int num_entries;
} PerlaHV;

typedef struct {
    SV **ary;
    SSize_t fill;
    SSize_t max;
} PerlaAV;



/* ============================================================
 * XS Function Registry
 * ============================================================ */

typedef struct xs_entry {
    char *name;
    XSUBADDR_t func;
    struct xs_entry *next;
} XSEntry;

#define XS_HASH_SIZE 256
static XSEntry *xs_registry[XS_HASH_SIZE] = {0};

static unsigned int xs_hash(const char *s) {
    unsigned int h = 5381;
    while (*s) h = h * 33 + (unsigned char)*s++;
    return h % XS_HASH_SIZE;
}

static void xs_register(const char *name, XSUBADDR_t func) {
    unsigned int h = xs_hash(name);
    XSEntry *e = malloc(sizeof(XSEntry));
    e->name = strdup(name);
    e->func = func;
    e->next = xs_registry[h];
    xs_registry[h] = e;
}

static XSUBADDR_t xs_lookup(const char *name) {
    unsigned int h = xs_hash(name);
    for (XSEntry *e = xs_registry[h]; e; e = e->next) {
        if (strcmp(e->name, name) == 0) return e->func;
    }
    return NULL;
}

/* Forward declarations */
static void cv_register(const char *name, CV *cv);

/* ============================================================
 * CV (Code Value) — wraps an XS function pointer
 * ============================================================ */

/* Override Perl_newXS — allocate a real XPVCV body so CvXSUB/CvXSUBANY/CvGV work */
CV* Perl_newXS(pTHX_ const char *name, XSUBADDR_t func, const char *file) {
    CV *cv = (CV*)calloc(1, sizeof(CV));
    cv->sv_refcnt = 1;
    cv->sv_flags = SVt_PVCV;

    /* Allocate a real XPVCV body — matches Perl's layout exactly */
    XPVCV *body = (XPVCV*)calloc(1, sizeof(XPVCV));
    body->xcv_root_u.xcv_xsub = func;   /* CvXSUB(cv) */
    if (file) body->xcv_file = strdup(file);
    cv->sv_any = (void*)body;

    /* Create a GV for CvGV — DBI uses GvNAME(CvGV(cv)) */
    GV *gv = (GV*)calloc(1, sizeof(GV));
    gv->sv_refcnt = 1;
    gv->sv_flags = SVt_PVGV;
    if (name) {
        const char *last_colon = strrchr(name, ':');
        const char *method_name = last_colon ? last_colon + 1 : name;
        /* GvNAME needs a HEK. Simplify: store name in GV's pv field
         * and override GvNAME to use it. For now use sv_u.svu_pv */
        gv->sv_u.svu_pv = strdup(method_name);
    }
    body->xcv_gv_u.xcv_gv = gv;  /* CvGV(cv) */

    static int xs_count = 0; xs_count++; if (name) fprintf(stderr, "  XS[%d] %s\n", xs_count, name);
    /* Register in our lookup tables */
    if (name) {
        xs_register(name, func);
        cv_register(name, cv);
    }

    return cv;
}

CV* Perl_newXS_deffile(pTHX_ const char *name, XSUBADDR_t func) {
    return Perl_newXS(aTHX_ name, func, "perla");
}

CV* Perl_newXS_flags(pTHX_ const char *name, XSUBADDR_t func, const char *file, const char *proto, U32 flags) {
    return Perl_newXS(aTHX_ name, func, file);
}

/* ============================================================
 * Magic — DBI uses this for handle tracking
 * ============================================================ */

typedef struct perla_magic {
    int mg_type;
    const MGVTBL *mg_virtual;
    char *mg_ptr;
    I32 mg_len;
    SV *mg_obj;
    struct perla_magic *mg_next;
} PerlaMagic;

/* Store magic in sv_any for non-body SVs, or in a side table */
/* Simple approach: use a global hash from SV* → magic chain */

#define MAGIC_TABLE_SIZE 1024
static struct { SV *sv; PerlaMagic *chain; } magic_table[MAGIC_TABLE_SIZE];

static PerlaMagic** magic_slot(const SV *sv) {
    unsigned int h = ((uintptr_t)sv >> 4) % MAGIC_TABLE_SIZE;
    for (int i = 0; i < MAGIC_TABLE_SIZE; i++) {
        int idx = (h + i) % MAGIC_TABLE_SIZE;
        if (magic_table[idx].sv == sv) return &magic_table[idx].chain;
        if (magic_table[idx].sv == NULL) {
            magic_table[idx].sv = (SV*)sv;
            return &magic_table[idx].chain;
        }
    }
    return NULL;
}

MAGIC* Perl_mg_find(pTHX_ const SV *sv, int type) {
    PerlaMagic **slot = magic_slot(sv);
    if (!slot) return NULL;
    for (PerlaMagic *mg = *slot; mg; mg = mg->mg_next) {
        if (mg->mg_type == type) return (MAGIC*)mg;
    }
    return NULL;
}

void Perl_sv_magic(pTHX_ SV *sv, SV *obj, int how, const char *name, I32 namlen) {
    PerlaMagic **slot = magic_slot(sv);
    if (!slot) return;
    PerlaMagic *mg = calloc(1, sizeof(PerlaMagic));
    mg->mg_type = how;
    mg->mg_obj = obj;
    if (name && namlen > 0) {
        mg->mg_ptr = malloc(namlen);
        memcpy(mg->mg_ptr, name, namlen);
        mg->mg_len = namlen;
    } else if (name) {
        mg->mg_ptr = (char*)name;  /* DBI passes struct pointers as mg_ptr */
        mg->mg_len = namlen;
    }
    mg->mg_next = *slot;
    *slot = mg;

    /* Mark SV as having magic */
    sv->sv_flags |= SVt_PVMG;
}

MAGIC* Perl_sv_magicext(pTHX_ SV *sv, SV *obj, int how, const MGVTBL *vtbl, const char *name, I32 namlen) {
    PerlaMagic **slot = magic_slot(sv);
    if (!slot) return NULL;
    PerlaMagic *mg = calloc(1, sizeof(PerlaMagic));
    mg->mg_type = how;
    mg->mg_virtual = vtbl;
    mg->mg_obj = obj;
    mg->mg_ptr = (char*)name;
    mg->mg_len = namlen;
    mg->mg_next = *slot;
    *slot = mg;
    sv->sv_flags |= SVt_PVMG;
    return (MAGIC*)mg;
}

int Perl_sv_unmagic(pTHX_ SV *sv, int type) {
    PerlaMagic **slot = magic_slot(sv);
    if (!slot) return 0;
    PerlaMagic **prev = slot;
    PerlaMagic *mg = *slot;
    while (mg) {
        if (mg->mg_type == type) {
            *prev = mg->mg_next;
            free(mg);
            return 0;
        }
        prev = &mg->mg_next;
        mg = mg->mg_next;
    }
    return 0;
}

int Perl_mg_get(pTHX_ SV *sv) { return 0; }

/* ============================================================
 * Stash/GV — for method resolution
 * ============================================================ */

/* Simple stash: hash of package name → hash of method name → CV */
typedef struct stash_entry {
    char *pkg_name;
    CV **methods;      /* array of CVs */
    char **method_names;
    int num_methods;
    int capacity;
    struct stash_entry *next;
} StashEntry;

#define STASH_HASH_SIZE 128
static StashEntry *stash_table[STASH_HASH_SIZE] = {0};

static StashEntry* stash_get_or_create(const char *name) {
    unsigned int h = xs_hash(name) % STASH_HASH_SIZE;
    for (StashEntry *e = stash_table[h]; e; e = e->next) {
        if (strcmp(e->pkg_name, name) == 0) return e;
    }
    StashEntry *e = calloc(1, sizeof(StashEntry));
    e->pkg_name = strdup(name);
    e->capacity = 32;
    e->methods = calloc(32, sizeof(CV*));
    e->method_names = calloc(32, sizeof(char*));
    e->next = stash_table[h];
    stash_table[h] = e;
    return e;
}

static void stash_add_method(const char *pkg, const char *method, CV *cv) {
    StashEntry *s = stash_get_or_create(pkg);
    if (s->num_methods >= s->capacity) {
        s->capacity *= 2;
        s->methods = realloc(s->methods, s->capacity * sizeof(CV*));
        s->method_names = realloc(s->method_names, s->capacity * sizeof(char*));
    }
    s->methods[s->num_methods] = cv;
    s->method_names[s->num_methods] = strdup(method);
    s->num_methods++;
}

HV* Perl_gv_stashpv(pTHX_ const char *name, I32 flags) {
    /* Return an HV that represents the stash — we use the StashEntry */
    StashEntry *s = stash_get_or_create(name);
    /* Create an HV wrapper */
    HV *hv = (HV*)calloc(1, sizeof(HV));
    hv->sv_refcnt = 1;
    hv->sv_flags = SVt_PVHV;
    hv->sv_any = (void*)s;
    /* Store package name for HvNAME */
    hv->sv_u.svu_pv = strdup(name);
    return hv;
}

HV* Perl_gv_stashsv(pTHX_ SV *sv, I32 flags) {
    STRLEN len;
    char *name = Perl_sv_2pv_flags(aTHX_ sv, &len, 0);
    return Perl_gv_stashpv(aTHX_ name, flags);
}

GV* Perl_gv_fetchpv(pTHX_ const char *name, I32 flags, const svtype sv_type) {
    return NULL;
}

GV* Perl_gv_fetchmethod_autoload(pTHX_ HV *stash, const char *name, I32 autoload) {
    if (!stash || !stash->sv_any) return NULL;
    StashEntry *s = (StashEntry*)stash->sv_any;
    for (int i = 0; i < s->num_methods; i++) {
        if (strcmp(s->method_names[i], name) == 0) {
            /* Return a GV that wraps the CV */
            GV *gv = (GV*)calloc(1, sizeof(GV));
            gv->sv_refcnt = 1;
            gv->sv_flags = SVt_PVGV;
            gv->sv_u.svu_pv = strdup(name);
            /* Store CV reference — GvCV macro needs this */
            /* We'll use sv_any to store the CV pointer */
            gv->sv_any = (void*)s->methods[i];
            return gv;
        }
    }
    return NULL;
}

/* Bless — set the stash on an RV's referent */
SV* Perl_sv_bless(pTHX_ SV *sv, HV *stash) {
    if (!sv || !stash) return sv;
    /* Store stash name as magic for SvSTASH emulation */
    if (stash->sv_u.svu_pv) {
        Perl_sv_magic(aTHX_ SvROK(sv) ? SvRV(sv) : sv, (SV*)stash, 'P', stash->sv_u.svu_pv, strlen(stash->sv_u.svu_pv));
    }
    return sv;
}

int Perl_sv_isobject(pTHX_ SV *sv) {
    if (!sv || !SvROK(sv)) return 0;
    SV *rv = SvRV(sv);
    PerlaMagic **slot = magic_slot(rv);
    if (slot && *slot) return 1;
    return 0;
}

bool Perl_sv_derived_from(pTHX_ SV *sv, const char * const name) {
    /* Check if SV's class matches name */
    if (!sv || !SvROK(sv)) return 0;
    SV *rv = SvRV(sv);
    PerlaMagic **slot = magic_slot(rv);
    if (!slot) return 0;
    for (PerlaMagic *mg = *slot; mg; mg = mg->mg_next) {
        if (mg->mg_type == 'P' && mg->mg_ptr && strcmp(mg->mg_ptr, name) == 0)
            return 1;
    }
    return 0;
}

/* ============================================================
 * call_sv / call_method — actually call XS functions
 * ============================================================ */

SSize_t Perl_call_sv(pTHX_ SV *sv, I32 flags) {
    CV *cv = NULL;

    if (SvTYPE(sv) == SVt_PVCV) {
        cv = (CV*)sv;
    } else if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV) {
        cv = (CV*)SvRV(sv);
    }

    if (!cv || !cv->sv_any) {
        fprintf(stderr, "call_sv: not a code reference\n");
        return 0;
    }

    XSUBADDR_t xsub = CvXSUB(cv);
    if (!xsub) {
        fprintf(stderr, "call_sv: no XS function\n");
        return 0;
    }

    /* Call the XS function — it uses the Perl stack directly */
    xsub(aTHX_ cv);

    return (SSize_t)(PL_stack_sp - PL_stack_base - TOPMARK);
}

SSize_t Perl_call_method(pTHX_ const char *methname, I32 flags) {
    /* The object is on the stack (ST(0)) */
    /* Look up the method through the stash */

    /* For DBI, methods are registered as "DBI::connect", "DBI::db::do", etc. */
    /* Try looking up as a fully qualified XS function */
    XSUBADDR_t func = xs_lookup(methname);

    if (!func) {
        /* Try with "DBI::" prefix */
        char buf[256];
        snprintf(buf, sizeof(buf), "DBI::%s", methname);
        func = xs_lookup(buf);
    }

    if (func) {
        /* Create a temporary CV with proper XPVCV body */
        CV cv_tmp;
        XPVCV body_tmp;
        GV gv_tmp;
        memset(&cv_tmp, 0, sizeof(CV));
        memset(&body_tmp, 0, sizeof(XPVCV));
        memset(&gv_tmp, 0, sizeof(GV));
        cv_tmp.sv_flags = SVt_PVCV;
        body_tmp.xcv_root_u.xcv_xsub = func;
        gv_tmp.sv_u.svu_pv = (char*)methname;
        body_tmp.xcv_gv_u.xcv_gv = &gv_tmp;
        cv_tmp.sv_any = (void*)&body_tmp;

        func(aTHX_ &cv_tmp);
        return (SSize_t)(PL_stack_sp - PL_stack_base);
    }

    fprintf(stderr, "call_method: can't find '%s'\n", methname);
    return 0;
}

/* ============================================================
 * Boot sequence — register XS functions from boot_ functions
 * ============================================================ */

/* These are called by Perla's initialization code */
extern void boot_DBI(pTHX_ CV *cv);
extern void boot_DBD__mysql(pTHX_ CV *cv);

void perla_xs_init(void) {
    /* Initialize our Perl API */
    extern void perla_perl_api_init(void);
    perla_perl_api_init();

    /* Create a dummy CV for boot functions */
    CV dummy_cv;
    memset(&dummy_cv, 0, sizeof(CV));
    dummy_cv.sv_flags = SVt_PVCV;

    /* Boot DBI — this registers all DBI XS functions */
    boot_DBI(aTHX_ &dummy_cv);

    /* Boot DBD::mysql — registers driver functions */
    boot_DBD__mysql(aTHX_ &dummy_cv);
}

/* ============================================================
 * CvGV / GvNAME support for DBI dispatcher
 * ============================================================ */

/* DBI uses: const char *meth_name = GvNAME(CvGV(cv))
 * CvGV(cv) returns the GV associated with the CV
 * GvNAME(gv) returns the name string from the GV
 *
 * In our implementation:
 *   CvGV(cv) → ((PerlaCVBody*)cv->sv_any)->gv
 *   GvNAME(gv) → gv->sv_u.svu_pv
 *
 * We need to make these macros work. They're defined in Perl headers
 * but rely on XPV bodies. Override them here.
 */

/* These are typically macros in Perl — we provide function versions
 * that DBI can call (via the #define overrides in our compat layer) */

/* The key DBI accessor: CvXSUBANY(cv).any_ptr
 * DBI stores its ima (method attribute) structure there */

/* For our CV, CvXSUBANY maps to ((PerlaCVBody*)cv->sv_any)->any */

/* Lookup CV by registered XS name — called by Perl_get_cv */
typedef struct cv_entry { char *name; CV *cv; struct cv_entry *next; } CVEntry;
static CVEntry *cv_registry_head = NULL;

static void cv_register(const char *name, CV *cv) {
    CVEntry *e = (CVEntry*)malloc(sizeof(CVEntry));
    e->name = strdup(name);
    e->cv = cv;
    e->next = cv_registry_head;
    cv_registry_head = e;
}

void* xs_lookup_cv(const char *name) {
    for (CVEntry *e = cv_registry_head; e; e = e->next) {
        if (strcmp(e->name, name) == 0) return e->cv;
    }
    return NULL;
}

/* Export body allocators for perla_perl_api.c */
void* perla_new_hv_body(void) {
    fprintf(stderr, "[DEBUG] new_hv_body\n");
    PerlaHV *body = (PerlaHV*)calloc(1, sizeof(PerlaHV));
    body->num_buckets = 16;
    body->buckets = (PerlaHE**)calloc(16, sizeof(PerlaHE*));
    return body;
}

void* perla_new_av_body(void) {
    PerlaAV *body = (PerlaAV*)calloc(1, sizeof(PerlaAV));
    body->fill = -1;
    body->max = 7;
    body->ary = (SV**)calloc(8, sizeof(SV*));
    return body;
}
