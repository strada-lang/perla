/*
 * perla_perl_api.c — Perl C API implementation for Perla
 *
 * Implements the ~130 Perl API functions that DBI.xs requires,
 * using Perl's own SV/AV/HV types (from real perl.h).
 * This is NOT a full Perl interpreter — just enough to run XS modules.
 *
 * Compile with: -I/opt/bzperl/lib/5.42.0/x86_64-linux/CORE
 */

/* We need Perl's real types */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/* ============================================================
 * Global Perl interpreter state (minimal)
 * ============================================================ */

/* Stack */
#define PERLA_STACK_SIZE 4096
static SV *perla_stack_store[PERLA_STACK_SIZE];
static I32 perla_markstack_store[256];

/* The Perl globals that DBI references */
PerlInterpreter *PL_curinterp = NULL;

/* We need a real PerlInterpreter for the PL_* macros to work.
 * Allocate a minimal one. */
static PerlInterpreter perla_interp_storage;

/* Immortal SVs */
static SV perla_sv_undef_body;
static SV perla_sv_yes_body;
static SV perla_sv_no_body;

static int perla_perl_api_initialized = 0;

void perla_perl_api_init(void) {
    if (perla_perl_api_initialized) return;
    perla_perl_api_initialized = 1;

    /* Initialize minimal interpreter */
    PL_curinterp = &perla_interp_storage;
    memset(PL_curinterp, 0, sizeof(PerlInterpreter));

    /* Set up stack */
    PL_stack_base = perla_stack_store;
    PL_stack_sp = perla_stack_store - 1;
    PL_stack_max = perla_stack_store + PERLA_STACK_SIZE - 1;

    PL_markstack = perla_markstack_store;
    PL_markstack_ptr = perla_markstack_store - 1;
    PL_markstack_max = perla_markstack_store + 255;

    /* Immortals */
    memset(&perla_sv_undef_body, 0, sizeof(SV));
    memset(&perla_sv_yes_body, 0, sizeof(SV));
    memset(&perla_sv_no_body, 0, sizeof(SV));

    perla_sv_yes_body.sv_flags = SVt_IV | SVf_IOK | SVp_IOK;
    perla_sv_yes_body.sv_u.svu_iv = 1;
    perla_sv_yes_body.sv_refcnt = SvREFCNT_IMMORTAL;

    perla_sv_no_body.sv_flags = SVt_IV | SVf_IOK | SVp_IOK;
    perla_sv_no_body.sv_u.svu_iv = 0;
    perla_sv_no_body.sv_refcnt = SvREFCNT_IMMORTAL;

    perla_sv_undef_body.sv_flags = SVt_NULL;
    perla_sv_undef_body.sv_refcnt = SvREFCNT_IMMORTAL;

    /* PL_sv_undef, PL_sv_yes, PL_sv_no are PL_sv_immortals[0], [1], [2] */
    PL_sv_immortals[0] = perla_sv_undef_body;
    PL_sv_immortals[1] = perla_sv_yes_body;
    PL_sv_immortals[2] = perla_sv_no_body;
}

/* ============================================================
 * SV Allocator — minimal, just malloc-based
 * ============================================================ */

SV* Perl_newSV(pTHX_ STRLEN len) {
    SV *sv = (SV*)calloc(1, sizeof(SV));
    sv->sv_refcnt = 1;
    sv->sv_flags = SVt_NULL;
    if (len > 0) {
        sv->sv_u.svu_pv = (char*)calloc(1, len + 1);
        sv->sv_flags = SVt_PV | SVf_POK | SVp_POK;
    }
    return sv;
}

SV* Perl_newSViv(pTHX_ IV i) {
    SV *sv = (SV*)calloc(1, sizeof(SV));
    sv->sv_refcnt = 1;
    sv->sv_flags = SVt_IV | SVf_IOK | SVp_IOK;
    sv->sv_u.svu_iv = i;
    return sv;
}

SV* Perl_newSVuv(pTHX_ UV u) {
    SV *sv = (SV*)calloc(1, sizeof(SV));
    sv->sv_refcnt = 1;
    sv->sv_flags = SVt_IV | SVf_IOK | SVp_IOK;
    sv->sv_u.svu_uv = u;
    return sv;
}

SV* Perl_newSVnv(pTHX_ NV n) {
    SV *sv = (SV*)calloc(1, sizeof(SV));
    sv->sv_refcnt = 1;
    sv->sv_flags = SVt_NV | SVf_NOK | SVp_NOK;
    sv->sv_u.svu_nv = n;
    return sv;
}

SV* Perl_newSVpv(pTHX_ const char *s, STRLEN len) {
    if (!s) return Perl_newSV(aTHX_ 0);
    if (len == 0) len = strlen(s);
    SV *sv = (SV*)calloc(1, sizeof(SV));
    sv->sv_refcnt = 1;
    sv->sv_flags = SVt_PV | SVf_POK | SVp_POK;
    sv->sv_u.svu_pv = (char*)malloc(len + 1);
    memcpy(sv->sv_u.svu_pv, s, len);
    sv->sv_u.svu_pv[len] = '\0';
    /* Store length in body — but we don't have XPV body allocated.
     * For minimal compat, we'll use strlen() when needed. */
    return sv;
}

SV* Perl_newSVpvn(pTHX_ const char *s, STRLEN len) {
    return Perl_newSVpv(aTHX_ s, len);
}

SV* Perl_newSVpvf(pTHX_ const char *fmt, ...) {
    char buf[8192];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    return Perl_newSVpv(aTHX_ buf, 0);
}

SV* Perl_newSVsv_flags(pTHX_ SV * const old, I32 flags) {
    if (!old) return Perl_newSV(aTHX_ 0);
    if (SvIOK(old)) return Perl_newSViv(aTHX_ SvIVX(old));
    if (SvNOK(old)) return Perl_newSVnv(aTHX_ SvNVX(old));
    if (SvPOK(old)) return Perl_newSVpv(aTHX_ SvPVX(old), 0);
    return Perl_newSV(aTHX_ 0);
}

SV* Perl_newRV(pTHX_ SV *referent) {
    SV *rv = (SV*)calloc(1, sizeof(SV));
    rv->sv_refcnt = 1;
    rv->sv_flags = SVt_IV | SVf_ROK;
    rv->sv_u.svu_rv = referent;
    if (referent) SvREFCNT_inc(referent);
    return rv;
}

/* ============================================================
 * SV Access
 * ============================================================ */

IV Perl_sv_2iv_flags(pTHX_ SV *sv, I32 flags) {
    if (!sv) return 0;
    if (SvIOK(sv)) return SvIVX(sv);
    if (SvNOK(sv)) return (IV)SvNVX(sv);
    if (SvPOK(sv)) return atol(SvPVX(sv));
    return 0;
}

UV Perl_sv_2uv_flags(pTHX_ SV *sv, I32 flags) {
    return (UV)Perl_sv_2iv_flags(aTHX_ sv, flags);
}

NV Perl_sv_2nv_flags(pTHX_ SV *sv, I32 flags) {
    if (!sv) return 0.0;
    if (SvNOK(sv)) return SvNVX(sv);
    if (SvIOK(sv)) return (NV)SvIVX(sv);
    if (SvPOK(sv)) return atof(SvPVX(sv));
    return 0.0;
}

char* Perl_sv_2pv_flags(pTHX_ SV *sv, STRLEN *lp, U32 flags) {
    static char numbuf[64];
    if (!sv || SvTYPE(sv) == SVt_NULL) {
        if (lp) *lp = 0;
        return "";
    }
    if (SvPOK(sv)) {
        if (lp) *lp = strlen(SvPVX(sv));
        return SvPVX(sv);
    }
    if (SvIOK(sv)) {
        snprintf(numbuf, sizeof(numbuf), "%ld", (long)SvIVX(sv));
        if (lp) *lp = strlen(numbuf);
        return numbuf;
    }
    if (SvNOK(sv)) {
        snprintf(numbuf, sizeof(numbuf), "%.15g", SvNVX(sv));
        if (lp) *lp = strlen(numbuf);
        return numbuf;
    }
    if (lp) *lp = 0;
    return "";
}

char* Perl_sv_2pvbyte_flags(pTHX_ SV *sv, STRLEN *lp, U32 flags) {
    return Perl_sv_2pv_flags(aTHX_ sv, lp, flags);
}

bool Perl_sv_2bool_flags(pTHX_ SV *sv, I32 flags) {
    if (!sv) return 0;
    if (SvIOK(sv)) return SvIVX(sv) != 0;
    if (SvNOK(sv)) return SvNVX(sv) != 0.0;
    if (SvPOK(sv)) return SvPVX(sv) && SvPVX(sv)[0] != '\0' && strcmp(SvPVX(sv), "0") != 0;
    if (SvROK(sv)) return 1;
    return 0;
}

/* ============================================================
 * SV Modification
 * ============================================================ */

void Perl_sv_setiv(pTHX_ SV *sv, IV i) {
    if (!sv) return;
    sv->sv_flags = (sv->sv_flags & ~(SVf_POK|SVf_NOK|SVf_ROK|SVp_POK|SVp_NOK)) | SVt_IV | SVf_IOK | SVp_IOK;
    sv->sv_u.svu_iv = i;
}
void Perl_sv_setiv_mg(pTHX_ SV *sv, IV i) { Perl_sv_setiv(aTHX_ sv, i); }

void Perl_sv_setnv(pTHX_ SV *sv, NV n) {
    if (!sv) return;
    sv->sv_flags = (sv->sv_flags & ~(SVf_POK|SVf_IOK|SVf_ROK|SVp_POK|SVp_IOK)) | SVt_NV | SVf_NOK | SVp_NOK;
    sv->sv_u.svu_nv = n;
}
void Perl_sv_setnv_mg(pTHX_ SV *sv, NV n) { Perl_sv_setnv(aTHX_ sv, n); }

void Perl_sv_setpv(pTHX_ SV *sv, const char *s) {
    if (!sv) return;
    if (SvPOK(sv) && sv->sv_u.svu_pv) free(sv->sv_u.svu_pv);
    sv->sv_flags = SVt_PV | SVf_POK | SVp_POK;
    sv->sv_u.svu_pv = s ? strdup(s) : strdup("");
}

void Perl_sv_setpvn(pTHX_ SV *sv, const char *s, STRLEN len) {
    if (!sv) return;
    if (SvPOK(sv) && sv->sv_u.svu_pv) free(sv->sv_u.svu_pv);
    sv->sv_flags = SVt_PV | SVf_POK | SVp_POK;
    sv->sv_u.svu_pv = (char*)malloc(len + 1);
    if (s) memcpy(sv->sv_u.svu_pv, s, len);
    sv->sv_u.svu_pv[len] = '\0';
}

void Perl_sv_setpvf(pTHX_ SV *sv, const char *fmt, ...) {
    char buf[8192];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    Perl_sv_setpv(aTHX_ sv, buf);
}

void Perl_sv_setsv_flags(pTHX_ SV *dsv, SV *ssv, I32 flags) {
    if (!dsv || !ssv) return;
    if (SvIOK(ssv)) Perl_sv_setiv(aTHX_ dsv, SvIVX(ssv));
    else if (SvNOK(ssv)) Perl_sv_setnv(aTHX_ dsv, SvNVX(ssv));
    else if (SvPOK(ssv)) Perl_sv_setpv(aTHX_ dsv, SvPVX(ssv));
}

void Perl_sv_catpv(pTHX_ SV *sv, const char *s) {
    if (!sv || !s) return;
    STRLEN old_len = SvPOK(sv) && sv->sv_u.svu_pv ? strlen(sv->sv_u.svu_pv) : 0;
    STRLEN add_len = strlen(s);
    char *new_str = (char*)malloc(old_len + add_len + 1);
    if (SvPOK(sv) && sv->sv_u.svu_pv) {
        memcpy(new_str, sv->sv_u.svu_pv, old_len);
        free(sv->sv_u.svu_pv);
    }
    memcpy(new_str + old_len, s, add_len + 1);
    sv->sv_u.svu_pv = new_str;
    sv->sv_flags |= SVt_PV | SVf_POK | SVp_POK;
}

void Perl_sv_catpvn_flags(pTHX_ SV *sv, const char *s, STRLEN len, I32 flags) {
    if (!sv || !s) return;
    STRLEN old_len = SvPOK(sv) && sv->sv_u.svu_pv ? strlen(sv->sv_u.svu_pv) : 0;
    char *new_str = (char*)malloc(old_len + len + 1);
    if (SvPOK(sv) && sv->sv_u.svu_pv) {
        memcpy(new_str, sv->sv_u.svu_pv, old_len);
        free(sv->sv_u.svu_pv);
    }
    memcpy(new_str + old_len, s, len);
    new_str[old_len + len] = '\0';
    sv->sv_u.svu_pv = new_str;
    sv->sv_flags |= SVt_PV | SVf_POK | SVp_POK;
}

void Perl_sv_catpvf(pTHX_ SV *sv, const char *fmt, ...) {
    char buf[8192];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    Perl_sv_catpv(aTHX_ sv, buf);
}

void Perl_sv_catsv_flags(pTHX_ SV *dsv, SV *ssv, I32 flags) {
    if (!ssv) return;
    STRLEN len;
    char *s = Perl_sv_2pv_flags(aTHX_ ssv, &len, 0);
    Perl_sv_catpvn_flags(aTHX_ dsv, s, len, 0);
}

/* ============================================================
 * Mortal / refcount
 * ============================================================ */

SV* Perl_sv_2mortal(pTHX_ SV *sv) {
    /* In full Perl, mortals go on the temps stack and are freed at scope exit.
     * For our minimal impl, just return the SV. Caller is responsible. */
    return sv;
}

SV* Perl_sv_newmortal(pTHX) {
    return Perl_newSV(aTHX_ 0);
}

SV* Perl_sv_mortalcopy_flags(pTHX_ SV *sv, U32 flags) {
    return Perl_newSVsv_flags(aTHX_ sv, flags);
}

void Perl_sv_free(pTHX_ SV *sv) {
    if (!sv || sv->sv_refcnt == SvREFCNT_IMMORTAL) return;
    if (SvPOK(sv) && sv->sv_u.svu_pv) free(sv->sv_u.svu_pv);
    free(sv);
}

void Perl_sv_free2(pTHX_ SV *sv, U32 rc) {
    Perl_sv_free(aTHX_ sv);
}

/* ============================================================
 * AV (Array) operations
 * ============================================================ */

/* Minimal AV: we store the array inline in sv_u.svu_array */
/* This won't work with Perl's real XPVAV body, but DBI mostly
 * uses av_push/av_fetch/av_len which we can implement simply. */

/* For a proper implementation, we'd need to allocate XPVAV bodies.
 * For now, use a simple approach: store an array of SV* as the body. */

typedef struct {
    SV **ary;
    SSize_t fill;   /* index of last element */
    SSize_t max;    /* allocated size - 1 */
} PerlaAV;

static PerlaAV* get_av_body(AV *av) {
    if (!av) return NULL;
    return (PerlaAV*)av->sv_any;
}

static AV* perla_newAV(void) {
    AV *av = (AV*)calloc(1, sizeof(AV));
    av->sv_refcnt = 1;
    av->sv_flags = SVt_PVAV;
    PerlaAV *body = (PerlaAV*)calloc(1, sizeof(PerlaAV));
    body->fill = -1;
    body->max = 7;
    body->ary = (SV**)calloc(8, sizeof(SV*));
    av->sv_any = (void*)body;
    return av;
}

void Perl_av_push(pTHX_ AV *av, SV *val) {
    PerlaAV *body = get_av_body(av);
    if (!body) return;
    body->fill++;
    if (body->fill > body->max) {
        body->max = body->max * 2 + 1;
        body->ary = (SV**)realloc(body->ary, (body->max + 1) * sizeof(SV*));
    }
    body->ary[body->fill] = val;
}

SV** Perl_av_fetch(pTHX_ AV *av, SSize_t key, I32 lval) {
    PerlaAV *body = get_av_body(av);
    if (!body || key < 0 || key > body->fill) return NULL;
    return &body->ary[key];
}

SV** Perl_av_store(pTHX_ AV *av, SSize_t key, SV *val) {
    PerlaAV *body = get_av_body(av);
    if (!body) return NULL;
    while (key > body->max) {
        body->max = body->max * 2 + 1;
        body->ary = (SV**)realloc(body->ary, (body->max + 1) * sizeof(SV*));
    }
    if (key > body->fill) body->fill = key;
    body->ary[key] = val;
    return &body->ary[key];
}

SSize_t Perl_av_len(pTHX_ AV *av) {
    PerlaAV *body = get_av_body(av);
    return body ? body->fill : -1;
}

void Perl_av_extend(pTHX_ AV *av, SSize_t key) {
    PerlaAV *body = get_av_body(av);
    if (!body) return;
    while (key > body->max) {
        body->max = body->max * 2 + 1;
        body->ary = (SV**)realloc(body->ary, (body->max + 1) * sizeof(SV*));
    }
}

void Perl_av_fill(pTHX_ AV *av, SSize_t fill) {
    PerlaAV *body = get_av_body(av);
    if (body) body->fill = fill;
}

SV* Perl_av_shift(pTHX_ AV *av) {
    PerlaAV *body = get_av_body(av);
    if (!body || body->fill < 0) return &PL_sv_undef;
    SV *val = body->ary[0];
    memmove(body->ary, body->ary + 1, body->fill * sizeof(SV*));
    body->fill--;
    return val ? val : &PL_sv_undef;
}

AV* Perl_av_make(pTHX_ SSize_t size, SV **svp) {
    AV *av = perla_newAV();
    for (SSize_t i = 0; i < size; i++) {
        Perl_av_push(aTHX_ av, svp[i]);
    }
    return av;
}

SV* Perl_av_pop(pTHX_ AV *av) {
    PerlaAV *body = get_av_body(av);
    if (!body || body->fill < 0) return &PL_sv_undef;
    SV *val = body->ary[body->fill];
    body->fill--;
    return val ? val : &PL_sv_undef;
}

/* ============================================================
 * HV (Hash) — using Perl's real XPVHV + HE layout
 * ============================================================ */

/* Use Perl's own HE struct for hash entries (defined in hv.h) */
/* HvARRAY(hv) = hv->sv_u.svu_hash (HE** bucket array) */
/* HvMAX(hv) = ((XPVHV*)hv->sv_any)->xhv_max (mask = num_buckets - 1) */

static unsigned int perla_hv_hash(const char *key, STRLEN klen) {
    unsigned int h = 5381;
    for (STRLEN i = 0; i < klen; i++) h = h * 33 + (unsigned char)key[i];
    return h;
}

/* Ensure HV has been initialized with bucket array */
static void hv_ensure_init(HV *hv) {
    if (!hv) return;
    if (!HvARRAY(hv)) {
        HvMAX(hv) = 15;  /* 16 buckets, mask = 15 */
        HvARRAY(hv) = (HE**)calloc(16, sizeof(HE*));
    }
}

void* Perl_hv_common_key_len(pTHX_ HV *hv, const char *key, I32 klen, const int action, SV *val, const U32 hash) {
    if (!hv) return NULL;
    hv_ensure_init(hv);

    STRLEN key_len = klen > 0 ? klen : strlen(key);
    unsigned int h = hash ? hash : perla_hv_hash(key, key_len);
    unsigned int idx = h & HvMAX(hv);

    /* Search existing entries */
    HE **oentry = &HvARRAY(hv)[idx];
    HE *entry;
    for (entry = *oentry; entry; entry = HeNEXT(entry)) {
        if (HeKLEN(entry) == (I32)key_len && memcmp(HeKEY(entry), key, key_len) == 0) {
            if (action & 0x04) {  /* HV_DELETE */
                *oentry = HeNEXT(entry);
                HvTOTALKEYS(hv)--;
                return HeVAL(entry);
            }
            if (val) HeVAL(entry) = val;
            return &HeVAL(entry);
        }
        oentry = &HeNEXT(entry);
    }

    /* Not found */
    if (!val && !(action & 0x02)) return NULL;  /* fetch only, miss */

    /* Insert new entry */
    HE *new_entry = (HE*)calloc(1, sizeof(HE));
    /* Allocate HEK (hash entry key) */
    char *key_copy = (char*)malloc(key_len + 1);
    memcpy(key_copy, key, key_len);
    key_copy[key_len] = '\0';
    /* Store key data in HE — use the hek structure */
    /* For simplicity, store key pointer and length directly */
    HeKEY_hek(new_entry) = (HEK*)malloc(sizeof(HEK) + key_len + 1);
    HeKEY_hek(new_entry)->hek_hash = h;
    HeKEY_hek(new_entry)->hek_len = key_len;
    memcpy(HEK_KEY(HeKEY_hek(new_entry)), key, key_len + 1);

    HeVAL(new_entry) = val ? val : Perl_newSV(aTHX_ 0);
    HeNEXT(new_entry) = HvARRAY(hv)[idx];
    HvARRAY(hv)[idx] = new_entry;
    HvTOTALKEYS(hv)++;

    return &HeVAL(new_entry);
}

void* Perl_hv_common(pTHX_ HV *hv, SV *keysv, const char *key, STRLEN klen, int flags, int action, SV *val, U32 hash) {
    if (keysv && !key) {
        STRLEN len;
        key = Perl_sv_2pv_flags(aTHX_ keysv, &len, 0);
        klen = len;
    }
    return Perl_hv_common_key_len(aTHX_ hv, key, klen, action, val, hash);
}

void Perl_hv_clear(pTHX_ HV *hv) {
    if (!hv || !HvARRAY(hv)) return;
    STRLEN max = HvMAX(hv);
    for (STRLEN i = 0; i <= max; i++) {
        HE *entry = HvARRAY(hv)[i];
        while (entry) {
            HE *next = HeNEXT(entry);
            free(entry);
            entry = next;
        }
        HvARRAY(hv)[i] = NULL;
    }
    HvTOTALKEYS(hv) = 0;
}

/* HV iteration state */
static int hv_iter_bucket = 0;
static HE *hv_iter_he = NULL;

I32 Perl_hv_iterinit(pTHX_ HV *hv) {
    if (!hv) return 0;
    hv_iter_bucket = 0;
    hv_iter_he = NULL;
    return (I32)HvTOTALKEYS(hv);
}

HE* Perl_hv_iternext_flags(pTHX_ HV *hv, I32 flags) {
    if (!hv || !HvARRAY(hv)) return NULL;
    STRLEN max = HvMAX(hv);
    
    while (hv_iter_he == NULL && (STRLEN)hv_iter_bucket <= max) {
        hv_iter_he = HvARRAY(hv)[hv_iter_bucket++];
    }
    if (!hv_iter_he) return NULL;

    HE *result = hv_iter_he;
    hv_iter_he = HeNEXT(hv_iter_he);
    return result;
}

SV* Perl_hv_iternextsv(pTHX_ HV *hv, char **key, I32 *klen) {
    HE *he = Perl_hv_iternext_flags(aTHX_ hv, 0);
    if (!he) return NULL;
    if (key) *key = HeKEY(he);
    if (klen) *klen = HeKLEN(he);
    return HeVAL(he);
}

char* Perl_hv_iterkey(pTHX_ HE *he, I32 *klen) {
    if (!he) return "";
    if (klen) *klen = HeKLEN(he);
    return HeKEY(he);
}

SV* Perl_hv_iterval(pTHX_ HV *hv, HE *he) {
    return he ? HeVAL(he) : &PL_sv_undef;
}

I32 Perl_hv_placeholders_get(pTHX_ const HV *hv) { return 0; }

/* ============================================================
 * Error handling
 * ============================================================ */

void Perl_croak(pTHX_ const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "DBI error: %s\n", buf);
    /* In full Perl this would longjmp. For now, just print and continue. */
}

void Perl_croak_sv(pTHX_ SV *sv) {
    STRLEN len;
    char *msg = Perl_sv_2pv_flags(aTHX_ sv, &len, 0);
    fprintf(stderr, "DBI error: %s\n", msg);
}

void Perl_croak_xs_usage(const CV * const cv, const char * const params) {
    fprintf(stderr, "Usage: %s\n", params);
}

OP* Perl_die(pTHX_ const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "DBI die: %s\n", buf);
    return NULL;
}

void Perl_warn(pTHX_ const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s", buf);
}

void Perl_warn_sv(pTHX_ SV *sv) {
    STRLEN len;
    char *msg = Perl_sv_2pv_flags(aTHX_ sv, &len, 0);
    fprintf(stderr, "%s", msg);
}

/* ============================================================
 * Misc stubs — things DBI references but doesn't critically need
 * ============================================================ */

/* removed: SV* Perl_sv_bless(pTHX_ SV *sv, HV *stash) { retur */

/* removed: int Perl_sv_isobject(pTHX_ SV *sv) { return SvROK( */

/* removed: bool Perl_sv_derived_from(pTHX_ SV *sv, const char */

const char* Perl_sv_reftype(pTHX_ const SV *sv, int ob) {
    if (SvROK(sv)) {
        SV *rv = SvRV(sv);
        U32 type = SvTYPE(rv);
        if (type == SVt_PVAV) return "ARRAY";
        if (type == SVt_PVHV) return "HASH";
        if (type == SVt_PVCV) return "CODE";
        return "SCALAR";
    }
    return "";
}
void Perl_sv_dump(pTHX_ SV *sv) {}
/* removed: Perl_sv_magic */
/* removed: MAGIC* Perl_sv_magicext(pTHX_ SV *sv, SV *obj, int */

/* removed: int Perl_sv_unmagic(pTHX_ SV *sv, int type) { retu */

/* removed: MAGIC* Perl_mg_find(pTHX_ const SV *sv, int type)  */

/* removed: int Perl_mg_get(pTHX_ SV *sv) { return 0; } */

I32 Perl_mg_size(pTHX_ SV *sv) { return 0; }
/* sv_upgrade — change SV type and allocate appropriate body */
extern void* perla_new_hv_body(void);
extern void* perla_new_av_body(void);
void Perl_sv_upgrade(pTHX_ SV *sv, svtype new_type) {
    sv->sv_flags = (sv->sv_flags & ~0xFF) | new_type;
    if (new_type == SVt_PVHV && !sv->sv_any) {
        sv->sv_any = perla_new_hv_body();
    } else if (new_type == SVt_PVAV && !sv->sv_any) {
        sv->sv_any = perla_new_av_body();
    } else if (new_type == SVt_PVCV && !sv->sv_any) {
        sv->sv_any = calloc(1, sizeof(XPVCV));
    }
}
char* Perl_sv_grow(pTHX_ SV *sv, STRLEN newlen) { return SvPOK(sv) ? SvPVX(sv) : ""; }
void Perl_sv_force_normal_flags(pTHX_ SV *sv, U32 flags) {}
void Perl_sv_insert_flags(pTHX_ SV *sv, STRLEN offset, STRLEN len, const char *s, STRLEN slen, U32 flags) {}
SV* Perl_sv_rvweaken(pTHX_ SV *sv) { return sv; }
void Perl_sv_backoff(pTHX_ SV *sv) {}
void Perl_sv_inc(pTHX_ SV *sv) { if (SvIOK(sv)) sv->sv_u.svu_iv++; }
bool Perl_sv_utf8_decode(pTHX_ SV *sv) { return 1; }
bool Perl_sv_tainted(pTHX_ SV *sv) { return 0; }
void Perl_taint_proper(pTHX_ const char *f, const char *s) {}
int Perl_looks_like_number(pTHX_ SV *sv) {
    STRLEN len;
    char *s = Perl_sv_2pv_flags(aTHX_ sv, &len, 0);
    return s && len > 0 && ((*s >= '0' && *s <= '9') || *s == '-' || *s == '+' || *s == '.');
}
int Perl_grok_number(pTHX_ const char *s, STRLEN len, UV *result) {
    if (result) *result = (UV)atol(s);
    return 1;
}
void Perl_sv_setuv(pTHX_ SV *sv, UV u) { Perl_sv_setiv(aTHX_ sv, (IV)u); }

/* GV/Stash — minimal stubs */
/* removed: HV* Perl_gv_stashpv(pTHX_ const char *name, I32 fl */

/* removed: HV* Perl_gv_stashsv(pTHX_ SV *sv, I32 flags) { ret */

/* removed: GV* Perl_gv_fetchpv(pTHX_ const char *name, I32 fl */

/* Persistent named SV registry — for $DBI::_dbistate etc. */
typedef struct named_sv { char *name; SV *sv; struct named_sv *next; } NamedSV;
static NamedSV *named_sv_head = NULL;

SV* Perl_get_sv(pTHX_ const char *name, I32 flags) {
    /* Look up existing */
    for (NamedSV *n = named_sv_head; n; n = n->next) {
        if (strcmp(n->name, name) == 0) return n->sv;
    }
    /* Create new */
    NamedSV *n = (NamedSV*)malloc(sizeof(NamedSV));
    n->name = strdup(name);
    n->sv = Perl_newSV(aTHX_ 0);
    SvREFCNT_inc(n->sv);
    n->next = named_sv_head;
    named_sv_head = n;
    return n->sv;
}
/* get_cv — look up a registered XS function by name */
/* xs_lookup is defined in perla_perl_runtime.c */
extern void* xs_lookup_cv(const char *name);
CV* Perl_get_cv(pTHX_ const char *name, I32 flags) {
    return (CV*)xs_lookup_cv(name);
}
/* removed: GV* Perl_gv_fetchmethod_autoload(pTHX_ HV *stash,  */

void Perl_gv_efullname4(pTHX_ SV *sv, const GV *gv, const char *prefix, bool keepmain) {}
GV* Perl_gv_add_by_type(pTHX_ GV *gv, svtype type) { return gv; }
GV* Perl_cvgv_from_hek(pTHX_ CV *cv) { return NULL; }
struct mro_meta* Perl_mro_meta_init(pTHX_ HV *stash) { return NULL; }

/* Method/sub calls — minimal */
/* removed: SSize_t Perl_call_method(pTHX_ const char *methnam */

/* removed: SSize_t Perl_call_sv(pTHX_ SV *sv, I32 flags) { re */


/* XS registration */
/* removed: CV* Perl_newXS(pTHX_ const char *name, XSUBADDR_t  */

/* removed: CV* Perl_newXS_deffile(pTHX_ const char *name, XSU */

/* removed: CV* Perl_newXS_flags(pTHX_ const char *name, XSUBA */

void Perl_xs_boot_epilog(pTHX_ const SSize_t ax) {}
Stack_off_t Perl_xs_handshake(const U32 key, void *v_my_perl, const char *file, ...) { return 0; }

/* Require */
void Perl_require_pv(pTHX_ const char *name) {}

/* Memory */
void* Perl_safesysmalloc(size_t n) { return malloc(n); }
void* Perl_safesyscalloc(size_t n, size_t s) { return calloc(n, s); }
void* Perl_safesysrealloc(void *p, size_t n) { return realloc(p, n); }
void Perl_safesysfree(void *p) { free(p); }

/* Save/restore */
void Perl_save_I32(pTHX_ I32 *p) {}
void Perl_save_int(pTHX_ int *p) {}
void Perl_save_sptr(pTHX_ SV **p) {}

/* Stack */
I32* Perl_markstack_grow(pTHX) { return PL_markstack_ptr; }
SV** Perl_stack_grow(pTHX_ SV **sp, SV **p, SSize_t n) { return sp; }

/* SV pool */
void* Perl_more_bodies(pTHX_ svtype sv_type, size_t body_size, size_t arena_size) { return calloc(1, body_size); }
SV* Perl_more_sv(pTHX) { return Perl_newSV(aTHX_ 0); }

/* PerlIO */
PerlIO* PerlIO_open(const char *path, const char *mode) { return fopen(path, mode); }
int PerlIO_printf(PerlIO *f, const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = vfprintf(f, fmt, ap);
    va_end(ap); return r;
}
int PerlIO_puts(PerlIO *f, const char *s) { return fputs(s, f); }
int PerlIO_vprintf(PerlIO *f, const char *fmt, va_list ap) { return vfprintf(f, fmt, ap); }
int Perl_PerlIO_close(pTHX_ PerlIO *f) { return fclose(f); }
int Perl_PerlIO_flush(pTHX_ PerlIO *f) { return fflush(f); }
void Perl_PerlIO_setlinebuf(pTHX_ PerlIO *f) { setlinebuf(f); }
PerlIO* Perl_PerlIO_stderr(pTHX) { return stderr; }
PerlIO* Perl_PerlIO_stdout(pTHX) { return stdout; }
IO* Perl_sv_2io(pTHX_ SV *sv) { return NULL; }
void Perl_free_tmps(pTHX) {}

/* newSV_type handled by Perl inline + our sv_upgrade */
