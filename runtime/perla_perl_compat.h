/*
 * perla_perl_compat.h — Perl API compatibility layer for Perla
 *
 * Maps Perl's C API (perl.h) to Strada's runtime, allowing XS modules
 * to be compiled and linked against Perla instead of libperl.
 *
 * This enables DBI, DBD::mysql, and other XS modules to work with Perla.
 */

#ifndef PERLA_PERL_COMPAT_H
#define PERLA_PERL_COMPAT_H

#include "strada_runtime.h"
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/* ============================================================
 * Threading context macros (no-op in Perla, non-threaded)
 */
#define pTHX
#define pTHX_
#define aTHX
#define aTHX_
#define dTHX
#define dTHXa(x)
#define dVAR
#define dNOOP
#define PERL_UNUSED_VAR(x) ((void)(x))
#define PERL_UNUSED_ARG(x) ((void)(x))
#define PERL_UNUSED_CONTEXT

/* Version check macros */
#ifndef PERL_VERSION_GE
#define PERL_VERSION_GE(r,v,s) ((r) < 5 || ((r) == 5 && ((v) < 42 || ((v) == 42 && (s) <= 0))))
#endif
#ifndef PERL_VERSION_LT
#define PERL_VERSION_LT(r,v,s) (!PERL_VERSION_GE(r,v,s))
#endif

/* XS prototype macros */
#ifndef XSPROTO
#define XSPROTO(name) void (*name)(CV* cv)
#endif

/* Version comparison macros (xsubpp generates these) */
#ifndef PERL_VERSION_LE
#define PERL_VERSION_LE(r,v,s) 0  /* Always false — pretend we're newer than 5.21.5 */
#endif

/* Boot macro — xsubpp's newer branch */
#ifndef dXSBOOTARGSXSAPIVERCHK
#define dXSBOOTARGSXSAPIVERCHK dXSARGS; SV **mark = perla_stack
#endif

/* STATIC — xsubpp generates this */
#ifndef STATIC
#define STATIC static
#endif

/* CV/GV introspection stubs */
#define CvGV(cv) NULL
#define GvNAME(gv) ""
#define GvSTASH(gv) NULL
#define HvNAME(hv) ""
#define HvNAME_get(hv) ""
#define Perl_croak_nocontext(...) strada_die(__VA_ARGS__)

/* Magic virtual table — must be before MAGIC */
#ifndef PERLA_MGVTBL_DEFINED
#define PERLA_MGVTBL_DEFINED
typedef struct { void *svt_get; void *svt_set; void *svt_len; void *svt_clear; void *svt_free; void *svt_copy; void *svt_dup; void *svt_local; } MGVTBL;
#endif

/* Magic */
#define PERL_MAGIC_backref 0
#define PERL_MAGIC_ext 0
#define SvMAGICAL(sv) 0
#define mg_find(sv, type) NULL
#ifndef PERLA_MAGIC_DEFINED
#define PERLA_MAGIC_DEFINED
typedef struct perla_magic { struct perla_magic *mg_moremagic; int mg_type; void *mg_obj; void *mg_ptr; unsigned short mg_len; const MGVTBL *mg_virtual; } MAGIC;
#endif

/* Format macros for printf */
#ifndef UVxf
#define UVxf "lx"
#endif
#ifndef IVdf
#define IVdf "ld"
#endif
#ifndef UVuf
#define UVuf "lu"
#endif
#ifndef NVgf
#define NVgf "g"
#endif

/* MGVTBL already defined above */

/* PL_ interpreter globals — stubs */
#ifndef PL_sv_arenaroot
#define PL_sv_arenaroot NULL
#endif
#ifndef PL_sv_root
#define PL_sv_root NULL
#endif

/* sv_magicext — defined later after SV typedef */

/* Operator overloading */
#define SvAMAGIC(sv) 0
#define SvAMAGIC_off(sv) do {} while(0)
#define SvAMAGIC_on(sv) do {} while(0)
#define AMT_AMAGIC(amt) 0
#define AMT_AMAGIC_off(amt) do {} while(0)

/* SV type mask for SvTYPE extraction */
#define SVTYPEMASK 0xff
/* SvFLAGS — our SVs don't have flags, return type directly */
#define SvFLAGS(sv) ((sv) ? (sv)->type : 0)

/* PL_Sv — defined after SV typedef below */
#define sv_flags type  /* Map sv->sv_flags to sv->type for ToInstance.xs */
#define SvMAGIC(sv) NULL
#define SvTAINTED_on(sv) do {} while(0)
#define SvTAINTED_off(sv) do {} while(0)

/* SV flags */
#define SVf_ROK 0x800
#define SVs_PADTMP 0
#define SVs_TEMP 0

/* $_ — XS code uses DEFSV / GvSV(PL_defgv) to read and write the
 * default scalar variable. Wire it to perla_dollar_underscore so XS
 * modules like List::Util / Scalar::Util that block-call user code with
 * `$_` set to each element actually pass the value through. Without
 * this, every `first { $_ > N }` block evaluated with stale $_, and
 * `List::Util::first { $op =~ $_->{regex} }` returned the wrong entry
 * — broke SAC's special_op dispatch (-ident, -value, -in, -between). */
extern StradaValue *perla_dollar_underscore;
#define DEFSV perla_dollar_underscore
#define SAVE_DEFSV do {} while(0)

/* SV type constants */
#define SVt_NULL   0
#define SVt_IV     1
#define SVt_NV     2
#define SVt_PV     3
#define SVt_PVIV   4
#define SVt_PVNV   5
#define SVt_PVAV   6
#define SVt_PVHV   7
#define SVt_PVCV   8
#define SVt_PVGV   9
#define SVt_PVMG   10

/* Perl internal stubs — these access deep interpreter state that Perla doesn't have */
#define HvAUX(hv) ((void*)0)
#define HvMROMETA(hv) ((void*)0)
#define PL_stashcache NULL

/* Hash entry type — maps to our hash iteration */
typedef struct { StradaValue *key; StradaValue *val; } HE;
#define HeKEY(he) ((he) ? strada_to_str((he)->key) : "")
#define HeVAL(he) ((he) ? (he)->val : NULL)
#define HePV(he, len) ((he) ? strada_to_str((he)->key) : "")
#define hv_iternext(hv) ((HE*)NULL)
#define hv_iternext_flags(hv, flags) ((HE*)NULL)
#define hv_iterinit(hv) 0
#define hv_fetch_ent(hv, key, lval, hash) ((HE*)NULL)
#define hv_store_ent(hv, key, val, hash) ((HE*)NULL)

/* Call flags */
#ifndef G_METHOD
#define G_METHOD 0
#endif
#ifndef G_DISCARD
#define G_DISCARD 4
#endif
#ifndef G_EVAL
#define G_EVAL 8
#endif

/* Boolean constants */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

/* GV flags */
#define GV_ADDMULTI 0
#define GV_ADD 0
#define GVf_IMPORTED_SV 0
#define GVf_IMPORTED_AV 0
#define GVf_IMPORTED_HV 0
#define GVf_IMPORTED_CV 0

/* gv_init — stub */
#define gv_init(gv, stash, name, len, flags) do {} while(0)

/* MRO cache — fake structs to satisfy mop.c's HvAUX(stash)->xhv_mro_meta->pkg_gen */
struct perla_fake_mro_meta { unsigned long pkg_gen; unsigned long cache_gen; };
struct perla_fake_hv_aux { struct perla_fake_mro_meta *xhv_mro_meta; };
static struct perla_fake_mro_meta perla_fake_mro_meta_inst = {0, 0};
static struct perla_fake_hv_aux perla_fake_hv_aux_inst = {&perla_fake_mro_meta_inst};
#undef HvAUX
#define HvAUX(hv) (&perla_fake_hv_aux_inst)

/* CvXSUBANY — per-XS-function user data, used by Moose to store prehashed key index */
typedef union { long any_i32; void *any_ptr; double any_nv; } XSUBANY;
static XSUBANY perla_fake_xsubany = {0};
#define CvXSUBANY(cv) perla_fake_xsubany

/* ============================================================
 * Core Perl types mapped to Strada types
 * ============================================================ */

typedef StradaValue SV;
typedef StradaArray AV;
typedef StradaHash  HV;
typedef void        CV;  /* Code value — opaque for now */
typedef void        GV;  /* Glob value — opaque */
typedef void        IO;  /* I/O handle — opaque */
typedef int         I32;
typedef unsigned    U32;
typedef long        IV;
typedef unsigned long UV;
typedef double      NV;
typedef size_t      STRLEN;
typedef char        bool;

/* PL_ globals that need SV type */
static SV *PL_Sv = NULL;

/* sv_magicext — attach magic to an SV (stub: no-op in Perla) */
static inline MAGIC* sv_magicext(SV *sv, SV *obj, int how, const MGVTBL *vtbl, const char *name, long namlen) {
    (void)sv; (void)obj; (void)how; (void)vtbl; (void)name; (void)namlen;
    return NULL;
}

/* Perl interpreter — single global (Perla is not multi-threaded Perl) */
typedef struct {
    SV **stack_base;
    SV **stack_sp;
    SV **stack_max;
    I32 *markstack;
    I32 *markstack_ptr;
    I32 *markstack_max;
    SV  *errsv;       /* $@ */
    SV  *defsv;       /* $_ */
    int  tainted;
    int  dowarn;
    int  phase;
} PerlInterpreter;

/* Global interpreter instance.
 *
 * The critical state below (perla_interp, stack, markstack, immortal SVs)
 * is SHARED between the main Perla binary and any XS .so that dlopens
 * into it. Without sharing, an XS function would push return values onto
 * ITS OWN isolated stack and the main binary couldn't read them back.
 *
 * One file (perla_xsloader.c, linked into perla_runtime.a) defines
 * PERLA_XS_STATE_OWNER before including this header → provides storage.
 * Every other consumer (XS .so compiled via perla-xs-build) gets
 * `extern` declarations; RTLD_GLOBAL + perla's -rdynamic link makes
 * those externs resolve to the main binary's single instance.
 */
#ifdef PERLA_XS_STATE_OWNER
PerlInterpreter perla_interp = {0};
#else
extern PerlInterpreter perla_interp;
#endif
#define my_perl (&perla_interp)

/* ============================================================
 * Perl stack macros
 * ============================================================ */

/* Stack — use a simple array */
#define PERLA_STACK_SIZE 1024
#ifdef PERLA_XS_STATE_OWNER
SV *perla_stack[PERLA_STACK_SIZE];
SV **perla_sp = perla_stack - 1;
I32 perla_markstack[256];
I32 *perla_markstack_ptr = perla_markstack - 1;
#else
extern SV *perla_stack[];
extern SV **perla_sp;
extern I32 perla_markstack[];
extern I32 *perla_markstack_ptr;
#endif

#define PL_stack_base   perla_stack
#define PL_stack_sp     perla_sp
#define PL_stack_max    (perla_stack + PERLA_STACK_SIZE - 1)
#define PL_markstack_ptr perla_markstack_ptr
#define PL_markstack_max (perla_markstack + 255)

#define SP              perla_sp
#define dSP             SV **sp = perla_sp
#define SPAGAIN         sp = perla_sp
#define PUTBACK         perla_sp = sp
#define PUSHMARK(p)     (*++perla_markstack_ptr = (I32)(sp - perla_stack))
#define TOPMARK         (*perla_markstack_ptr)
#define POPMARK         (*perla_markstack_ptr--)

#define PUSHs(sv)       (*++sp = (sv))
#define XPUSHs(sv)      (*++sp = (sv))
#define POPs            (*sp--)
#define TOPs            (*sp)

#define ENTER           do {} while(0)
#define LEAVE           do {} while(0)
#define SAVETMPS        do {} while(0)
#define FREETMPS        do {} while(0)

#define XSRETURN(n)     do { perla_sp = sp; return; } while(0)
#define XSRETURN_YES    do { XPUSHs(&PL_sv_yes); XSRETURN(1); } while(0)
#define XSRETURN_NO     do { XPUSHs(&PL_sv_no); XSRETURN(1); } while(0)
#define XSRETURN_UNDEF  do { XPUSHs(strada_new_undef()); XSRETURN(1); } while(0)
#define XSRETURN_IV(iv) do { XPUSHs(Perl_newSViv(iv)); XSRETURN(1); } while(0)
#define XSRETURN_PV(pv) do { XPUSHs(Perl_newSVpv(pv, 0)); XSRETURN(1); } while(0)
#define XSRETURN_EMPTY  XSRETURN(0)

/* ============================================================
 * Immortal SVs (shared — see note above perla_interp)
 * ============================================================ */

#ifdef PERLA_XS_STATE_OWNER
SV perla_sv_undef_val = {0};
SV perla_sv_yes_val = {0};
SV perla_sv_no_val = {0};
#else
extern SV perla_sv_undef_val;
extern SV perla_sv_yes_val;
extern SV perla_sv_no_val;
#endif

#define PL_sv_undef     perla_sv_undef_val
#define PL_sv_yes       perla_sv_yes_val
#define PL_sv_no        perla_sv_no_val
#define PL_sv_immortals (&perla_sv_undef_val)
#define PL_sv_root      NULL
#define PL_sv_count     0

/* ============================================================
 * SV creation
 * ============================================================ */

static inline SV* Perl_newSV(int size) {
    return strada_new_undef();
}

static inline SV* Perl_newSViv(IV i) {
    return STRADA_MAKE_TAGGED_INT(i);
}

static inline SV* Perl_newSVuv(UV u) {
    return STRADA_MAKE_TAGGED_INT((IV)u);
}

static inline SV* Perl_newSVnv(NV n) {
    return strada_new_num(n);
}

static inline SV* Perl_newSVpv(const char *s, STRLEN len) {
    if (len == 0 && s) len = strlen(s);
    return strada_new_str_len(s, len);
}

static inline SV* Perl_newSVpvn(const char *s, STRLEN len) {
    return strada_new_str_len(s, len);
}

static inline SV* Perl_newSVpvf(const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    return strada_new_str(buf);
}

static inline SV* Perl_newSVsv_flags(SV *old, int flags) {
    if (!old || STRADA_IS_TAGGED_INT(old)) return old;
    strada_incref(old);
    return old;
}
#define newSVsv(sv)  Perl_newSVsv_flags(sv, 0)

static inline SV* Perl_newRV(SV *referent) {
    return strada_ref_create(referent);
}
#define newRV_noinc(sv)  Perl_newRV(sv)
#define newRV_inc(sv)    ({ strada_incref(sv); Perl_newRV(sv); })

/* ============================================================
 * SV access — extract values
 * ============================================================ */

static inline IV Perl_sv_2iv_flags(SV *sv, int flags) {
    return strada_to_int(sv);
}

static inline UV Perl_sv_2uv_flags(SV *sv, int flags) {
    return (UV)strada_to_int(sv);
}

static inline NV Perl_sv_2nv_flags(SV *sv, int flags) {
    return strada_to_num(sv);
}

static inline char* Perl_sv_2pv_flags(SV *sv, STRLEN *lp, int flags) {
    char *s = strada_to_str(sv);
    if (lp) *lp = s ? strlen(s) : 0;
    return s;  /* Caller must free — or we need a mortal pool */
}

static inline char* Perl_sv_2pvbyte_flags(SV *sv, STRLEN *lp, int flags) {
    return Perl_sv_2pv_flags(sv, lp, flags);
}

static inline bool Perl_sv_2bool_flags(SV *sv, int flags) {
    return strada_to_bool(sv);
}

#define SvIV(sv)        Perl_sv_2iv_flags(sv, 0)
#define SvIVx(sv)       SvIV(sv)
#define SvUV(sv)        Perl_sv_2uv_flags(sv, 0)
#define SvNV(sv)        Perl_sv_2nv_flags(sv, 0)
#define SvNVx(sv)       SvNV(sv)
#define SvPV(sv, len)   Perl_sv_2pv_flags(sv, &(len), 0)
#define SvPV_nolen(sv)  Perl_sv_2pv_flags(sv, NULL, 0)
#define SvPVbyte(sv,len) Perl_sv_2pvbyte_flags(sv, &(len), 0)
#define SvPVX(sv)       (((sv) && !STRADA_IS_TAGGED_INT(sv) && (sv)->type == STRADA_STR) ? (sv)->value.pv : "")
#define SvCUR(sv)       (((sv) && !STRADA_IS_TAGGED_INT(sv) && (sv)->type == STRADA_STR) ? strada_str_len(sv) : 0)
#define SvTRUE(sv)      strada_to_bool(sv)

/* SV type checks */
#define SvOK(sv)        (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type != STRADA_UNDEF)
#define SvIOK(sv)       (STRADA_IS_TAGGED_INT(sv) || (sv && sv->type == STRADA_INT))
#define SvNOK(sv)       (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type == STRADA_NUM)
#define SvPOK(sv)       (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type == STRADA_STR)
#define SvROK(sv)       (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type == STRADA_REF)
#define SvRV(sv)        (sv->value.rv)

/* SV modification — for heap SVs only (tagged ints are immortal & can't
 * be mutated through a raw pointer; callers must reassign the variable).
 * xsubpp-generated code always allocates a heap SV (sv_newmortal/TARG)
 * before calling sv_setiv, so this is the common case. */
static inline void Perl_sv_setiv(SV *sv, IV i) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_STR && sv->value.pv) { free(sv->value.pv); sv->value.pv = NULL; }
    sv->type = STRADA_INT;
    sv->value.iv = (int64_t)i;
}
#define Perl_sv_setiv_mg Perl_sv_setiv

static inline void Perl_sv_setnv(SV *sv, NV n) {
    if (sv && !STRADA_IS_TAGGED_INT(sv)) {
        sv->type = STRADA_NUM;
        sv->value.nv = n;
    }
}
#define Perl_sv_setnv_mg Perl_sv_setnv

static inline void Perl_sv_setpv(SV *sv, const char *s) {
    if (sv && !STRADA_IS_TAGGED_INT(sv)) {
        if (sv->type == STRADA_STR && sv->value.pv) free(sv->value.pv);
        sv->type = STRADA_STR;
        sv->value.pv = strdup(s ? s : "");
    }
}

static inline void Perl_sv_setpvn(SV *sv, const char *s, STRLEN len) {
    if (sv && !STRADA_IS_TAGGED_INT(sv)) {
        if (sv->type == STRADA_STR && sv->value.pv) free(sv->value.pv);
        sv->type = STRADA_STR;
        sv->value.pv = strndup(s, len);
    }
}

static inline void Perl_sv_setpvf(SV *sv, const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    Perl_sv_setpv(sv, buf);
}

static inline void Perl_sv_setsv_flags(SV *dsv, SV *ssv, int flags) {
    /* Simple: copy type and value */
    if (!dsv || STRADA_IS_TAGGED_INT(dsv)) return;
    if (STRADA_IS_TAGGED_INT(ssv)) {
        dsv->type = STRADA_INT;
        dsv->value.iv = STRADA_TAGGED_INT_VAL(ssv);
    } else if (ssv) {
        dsv->type = ssv->type;
        if (ssv->type == STRADA_STR && ssv->value.pv)
            dsv->value.pv = strdup(ssv->value.pv);
        else
            dsv->value = ssv->value;
    }
}
#define sv_setsv(d,s)  Perl_sv_setsv_flags(d, s, 0)
#define SvSetSV(d,s)   sv_setsv(d,s)

/* String operations */
static inline void Perl_sv_catpv(SV *sv, const char *s) {
    if (!sv || STRADA_IS_TAGGED_INT(sv) || sv->type != STRADA_STR) return;
    size_t old_len = sv->value.pv ? strlen(sv->value.pv) : 0;
    size_t add_len = s ? strlen(s) : 0;
    char *new_str = malloc(old_len + add_len + 1);
    if (sv->value.pv) memcpy(new_str, sv->value.pv, old_len);
    if (s) memcpy(new_str + old_len, s, add_len);
    new_str[old_len + add_len] = '\0';
    free(sv->value.pv);
    sv->value.pv = new_str;
}

static inline void Perl_sv_catpvn_flags(SV *sv, const char *s, STRLEN len, int flags) {
    if (!sv || STRADA_IS_TAGGED_INT(sv) || sv->type != STRADA_STR) return;
    size_t old_len = sv->value.pv ? strlen(sv->value.pv) : 0;
    char *new_str = malloc(old_len + len + 1);
    if (sv->value.pv) memcpy(new_str, sv->value.pv, old_len);
    memcpy(new_str + old_len, s, len);
    new_str[old_len + len] = '\0';
    free(sv->value.pv);
    sv->value.pv = new_str;
}

static inline void Perl_sv_catpvf(SV *sv, const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    Perl_sv_catpv(sv, buf);
}

static inline void Perl_sv_catsv_flags(SV *dsv, SV *ssv, int flags) {
    if (!ssv) return;
    char *s = strada_to_str(ssv);
    Perl_sv_catpv(dsv, s);
    free(s);
}

/* Mortal — in Perla, just return the SV (cleanup handled by refcounting) */
static inline SV* Perl_sv_2mortal(SV *sv) { return sv; }
static inline SV* Perl_sv_newmortal(void) { return strada_new_undef(); }
static inline SV* Perl_sv_mortalcopy_flags(SV *sv, int flags) {
    if (!sv) return strada_new_undef();
    strada_incref(sv);
    return sv;
}
#define sv_2mortal(sv) Perl_sv_2mortal(sv)
#define sv_mortalcopy(sv) Perl_sv_mortalcopy_flags(sv, 0)

/* Reference counting */
#define SvREFCNT(sv)     ((sv && !STRADA_IS_TAGGED_INT(sv)) ? sv->refcount : 1)
#define SvREFCNT_inc(sv) ({ if (sv) strada_incref(sv); sv; })
#define SvREFCNT_dec(sv) ({ if (sv) strada_decref(sv); })
#define Perl_sv_free(sv)  strada_decref(sv)
#define Perl_sv_free2(sv) strada_decref(sv)

/* Bless */
static inline SV* Perl_sv_bless(SV *sv, HV *stash) {
    /* stash name → blessed package name */
    /* For now, just return sv */
    return sv;
}

static inline bool Perl_sv_isobject(SV *sv) {
    return (sv && !STRADA_IS_TAGGED_INT(sv) && sv->meta && sv->meta->blessed_package);
}

static inline bool Perl_sv_derived_from(SV *sv, const char *name) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return 0;
    if (sv->meta && sv->meta->blessed_package)
        return strcmp(sv->meta->blessed_package, name) == 0;
    return 0;
}

static inline const char* Perl_sv_reftype(SV *sv, int ob) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return "";
    if (sv->type == STRADA_HASH) return "HASH";
    if (sv->type == STRADA_ARRAY) return "ARRAY";
    if (sv->type == STRADA_REF) return "REF";
    if (sv->type == STRADA_CLOSURE) return "CODE";
    return "SCALAR";
}

/* ============================================================
 * AV (Array) operations
 * ============================================================ */

static inline AV* Perl_av_make(I32 size, SV **svp) {
    /* Not implemented — return empty array */
    return (AV*)strada_new_array();
}

/* Small rotating pool so nested fetch calls in the same expression don't
 * clobber each other. Real Perl returns a pointer into the SV array on
 * the AV/HV; we don't expose that, so we just hand out rotating storage.
 * 16 slots is enough for any reasonable XS expression depth. */
#define PERLA_FETCH_POOL_SIZE 16
static SV *perla_fetch_pool[PERLA_FETCH_POOL_SIZE];
static int perla_fetch_pool_idx = 0;
static inline SV** perla_fetch_slot(SV *v) {
    perla_fetch_pool_idx = (perla_fetch_pool_idx + 1) & (PERLA_FETCH_POOL_SIZE - 1);
    perla_fetch_pool[perla_fetch_pool_idx] = v;
    return &perla_fetch_pool[perla_fetch_pool_idx];
}

static inline SV** Perl_av_fetch(AV *av, I32 key, I32 lval) {
    if (!av) return NULL;
    StradaValue *v = strada_array_get(av, key);
    if (!v) return NULL;
    return perla_fetch_slot(v);
}

static inline SV** Perl_av_store(AV *av, I32 key, SV *val) {
    if (!av) return NULL;
    strada_array_set(av, key, val);
    return perla_fetch_slot(val);
}

static inline void Perl_av_push(AV *av, SV *val) {
    if (av) strada_array_push(av, val);
}

static inline SV* Perl_av_pop(AV *av) {
    if (!av) return strada_new_undef();
    return strada_array_pop(av);
}

static inline SV* Perl_av_shift(AV *av) {
    if (!av) return strada_new_undef();
    return strada_array_shift(av);
}

static inline I32 Perl_av_len(AV *av) {
    if (!av) return -1;
    return (I32)av->size - 1;
}

static inline void Perl_av_extend(AV *av, I32 key) {
    /* Pre-allocate — no-op for now */
}

static inline void Perl_av_fill(AV *av, I32 fill) {
    /* Set array length — no-op for now */
}

/* ============================================================
 * HV (Hash) operations
 * ============================================================ */

static inline SV** Perl_hv_common_key_len(HV *hv, const char *key, I32 klen, int action, SV *val, U32 hash) {
    if (!hv) return NULL;
    SV *res;
    if (action & 0x02) {  /* HV_FETCH_ISSTORE */
        strada_hash_set(hv, key, val);
        res = val;
    } else {
        res = strada_hash_get(hv, key);
    }
    return res ? perla_fetch_slot(res) : NULL;
}

#define hv_store(hv, key, klen, val, hash) \
    Perl_hv_common_key_len(hv, key, klen, 0x02, val, hash)

#define hv_fetch(hv, key, klen, lval) \
    Perl_hv_common_key_len(hv, key, klen, 0, NULL, 0)

#define hv_delete(hv, key, klen, flags) \
    ({ strada_hash_delete(hv, key); (SV*)NULL; })

#define hv_exists(hv, key, klen) \
    (strada_hash_exists(hv, key))

static inline void Perl_hv_clear(HV *hv) {
    /* Clear all entries — not fully implemented */
}

static inline I32 Perl_hv_iterinit(HV *hv) {
    /* Start iteration — return count */
    if (!hv) return 0;
    hv->iter_index = 0;
    return (I32)hv->num_entries;
}

/* ============================================================
 * Error handling
 * ============================================================ */

static inline void Perl_croak(const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    strada_die("%s", buf);
}

static inline void Perl_croak_sv(SV *sv) {
    char *msg = strada_to_str(sv);
    strada_die("%s", msg);
    free(msg);
}

static inline void Perl_warn(const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s", buf);
}

static inline void Perl_warn_sv(SV *sv) {
    char *msg = strada_to_str(sv);
    fprintf(stderr, "%s", msg);
    free(msg);
}

static inline SV* Perl_die(const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    strada_die("%s", buf);
    return strada_new_undef();
}

/* ============================================================
 * Misc Perl globals and stubs
 * ============================================================ */

#define PL_errgv         NULL
/* PL_defgv — wired to a fake GV that holds &perla_dollar_underscore so
 * GvSV(PL_defgv) extracts perla's $_. See note on DEFSV above. */
typedef struct PerlaFakeGV { StradaValue **sv_ptr; } PerlaFakeGV;
extern PerlaFakeGV perla_defgv_storage;
#define PL_defgv         (&perla_defgv_storage)
#define PL_curcop        NULL
#define PL_curpad        NULL
#define PL_curstackinfo  NULL
#define PL_op            NULL
#define PL_DBsub         NULL
#define PL_tainted       0
#define PL_tainting      0
#define PL_dowarn        0
#define PL_phase         0
#define PL_perl_destruct_level 0
#define PL_sub_generation 0
#define PL_body_roots    NULL
#define PL_in_utf8_CTYPE_locale 0
#define PL_charclass     NULL
#define PL_latin1_lc     NULL
#define PL_mod_latin1_uc NULL

/* Memory */
#define Perl_safesysmalloc(n)   malloc(n)
#define Perl_safesyscalloc(n,s) calloc(n,s)
#define Perl_safesysrealloc(p,n) realloc(p,n)
#define Perl_safesysfree(p)     free(p)
#define Newx(p,n,t)             (p = (t*)malloc((n)*sizeof(t)))
#define Newxz(p,n,t)            (p = (t*)calloc(n, sizeof(t)))
#define Renew(p,n,t)            (p = (t*)realloc(p, (n)*sizeof(t)))
#define Safefree(p)             free(p)
#define Copy(s,d,n,t)           memcpy(d,s,(n)*sizeof(t))
#define Move(s,d,n,t)           memmove(d,s,(n)*sizeof(t))
#define Zero(d,n,t)             memset(d,0,(n)*sizeof(t))

/* String utilities */
#define savepv(s)               strdup(s)
#define savepvn(s,n)            strndup(s,n)
#define my_strlcpy(d,s,n)      strncpy(d,s,n)

/* GV/Stash stubs */
static inline HV* Perl_gv_stashpv(const char *name, int flags) { return NULL; }
static inline HV* Perl_gv_stashsv(SV *sv, int flags) { return NULL; }
static inline GV* Perl_gv_fetchpv(const char *name, int flags, int sv_type) { return NULL; }
static inline SV* Perl_get_sv(const char *name, int flags) { return strada_new_undef(); }
static inline CV* Perl_get_cv(const char *name, int flags) { return NULL; }

/* Method calls — route through Perla's stash */
static inline I32 Perl_call_method(const char *method, I32 flags) {
    /* Not yet implemented — would need stack-based dispatch */
    return 0;
}

static inline I32 Perl_call_sv(SV *sv, I32 flags) {
    /* Not yet implemented */
    return 0;
}

/* XS registration */
static inline CV* Perl_newXS(const char *name, void (*func)(CV*), const char *file) {
    return NULL;
}

static inline CV* Perl_newXS_flags(const char *name, void (*func)(CV*), const char *file, const char *proto, int flags) {
    return NULL;
}

static inline void Perl_xs_boot_epilog(I32 ax) {}
static inline U32 Perl_xs_handshake(U32 a, ...) { return 0; }

/* Magic — stubs */
/* MAGIC already defined above */
static inline MAGIC* Perl_mg_find(SV *sv, int type) { return NULL; }
static inline int Perl_mg_get(SV *sv) { return 0; }
static inline void Perl_sv_magic(SV *sv, SV *obj, int how, const char *name, I32 namlen) {}
static inline MAGIC* Perl_sv_magicext(SV *sv, SV *obj, int how, void *vtbl, const char *name, I32 namlen) { return NULL; }
static inline int Perl_sv_unmagic(SV *sv, int type) { return 0; }
static inline U32 Perl_mg_size(SV *sv) { return 0; }
static inline void Perl_sv_upgrade(SV *sv, int new_type) {}

/* Number parsing */
static inline int Perl_grok_number(const char *s, STRLEN len, UV *result) {
    if (result) *result = (UV)atol(s);
    return 1;
}

static inline int Perl_looks_like_number(SV *sv) {
    char *s = strada_to_str(sv);
    int result = (s && (s[0] >= '0' && s[0] <= '9' || s[0] == '-' || s[0] == '+' || s[0] == '.'));
    free(s);
    return result;
}

/* UTF-8 stubs */
static inline int Perl_sv_utf8_decode(SV *sv) { return 1; }
#define SvUTF8(sv)       0
#define SvUTF8_on(sv)    do {} while(0)
#define SvUTF8_off(sv)   do {} while(0)

/* Taint stubs */
static inline void Perl_taint_proper(const char *f, ...) {}
static inline int Perl_sv_tainted(SV *sv) { return 0; }

/* Save/restore stubs */
static inline void Perl_save_I32(I32 *p) {}
static inline void Perl_save_int(int *p) {}
static inline void Perl_save_sptr(SV **p) {}

/* SV misc */
static inline void Perl_sv_inc(SV *sv) {
    if (STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_INT) sv->value.iv++;
}

static inline SV* Perl_sv_grow(SV *sv, STRLEN len) { return sv; }
static inline void Perl_sv_force_normal_flags(SV *sv, int flags) {}
static inline void Perl_sv_dump(SV *sv) {}
static inline void Perl_sv_insert_flags(SV *sv, STRLEN offset, STRLEN len, const char *s, STRLEN slen, int flags) {}
static inline SV* Perl_sv_rvweaken(SV *sv) { return sv; }
static inline void Perl_sv_backoff(SV *sv) {}
static inline void Perl_sv_setuv(SV *sv, UV u) { Perl_sv_setiv(sv, (IV)u); }

/* GV/CV utilities */
static inline void* Perl_gv_fetchmethod_autoload(HV *stash, const char *name, I32 autoload) { return NULL; }
static inline void Perl_gv_efullname4(SV *sv, GV *gv, const char *prefix, int keepmain) {}
static inline GV* Perl_gv_add_by_type(GV *gv, int type) { return gv; }
static inline void* Perl_cvgv_from_hek(CV *cv) { return NULL; }
static inline void Perl_mro_meta_init(HV *stash) {}
static inline void* Perl_more_bodies(int sv_type, size_t body_size, size_t arena_size) { return malloc(body_size); }
static inline SV* Perl_more_sv(void) { return strada_new_undef(); }
static inline void Perl_require_pv(const char *name) {}
static inline void Perl_markstack_grow(void) {}
static inline void Perl_stack_grow(SV **sp, SV **p, int n) {}
static inline void Perl_croak_xs_usage(CV *cv, const char *params) { Perl_croak("Usage: %s", params); }
static inline I32 Perl_hv_placeholders_get(HV *hv) { return 0; }

/* PerlIO — map to stdio */
#define PerlIO               FILE
#define PerlIO_open(f,m)     fopen(f,m)
#define PerlIO_printf        fprintf
#define PerlIO_puts(f,s)     fputs(s,f)
#define PerlIO_vprintf       vfprintf
#define Perl_PerlIO_close(f) fclose(f)
#define Perl_PerlIO_flush(f) fflush(f)
#define Perl_PerlIO_stderr() stderr
#define Perl_PerlIO_stdout() stdout
#define Perl_PerlIO_setlinebuf(f) setlinebuf(f)

/* IO stub */
static inline IO* Perl_sv_2io(SV *sv) { return NULL; }

/* ============================================================
 * Convenience macros that Perl XS code commonly uses
 * ============================================================ */

#define dXSARGS \
    dSP; \
    I32 ax = (I32)(perla_markstack_ptr > perla_markstack ? TOPMARK + 1 : 0); \
    I32 items = (I32)(sp - perla_stack) - ax + 1

/* dXSTARG — declares a scratch SV for XSRETURN_IV / _NV / _PV to use.
 * In real Perl this is a padtmp with type-munging. For Perla it's fine
 * to point at a fresh SV; XSRETURN_IV etc. go through Perl_newSViv
 * regardless, so we only need the symbol to exist. */
#define dXSTARG SV *TARG = (SV*)0

/* XSprePUSH — normalizes the stack pointer before pushing a single
 * return value (used by RETVAL-style generated code). Real Perl pops
 * the args and leaves sp pointing one below the start. Ours is cheap:
 * rewind sp to the mark. */
#define XSprePUSH  (sp = perla_stack + (ax - 1))

#define ST(n)   (perla_stack[ax + (n)])

/* PUSHi / PUSHu / PUSHn / PUSHp — push a typed value onto the stack.
 * Real Perl uses sv_setiv_mg on TARG then PUSHs(TARG); our TARG is a
 * throwaway so we just allocate a fresh SV each time. Slightly more
 * GC churn, identical semantics. */
#define PUSHi(iv) do { XPUSHs(Perl_newSViv((IV)(iv))); } while (0)
#define PUSHu(uv) do { XPUSHs(Perl_newSVuv((UV)(uv))); } while (0)
#define PUSHn(nv) do { XPUSHs(Perl_newSVnv((NV)(nv))); } while (0)
#define PUSHp(ptr, len) do { XPUSHs(Perl_newSVpvn((const char*)(ptr), (STRLEN)(len))); } while (0)

/* PTR2UV / PTR2IV / PTR2NV / INT2PTR — pointer ↔ integer casts. */
#define PTR2UV(p)   ((UV)(uintptr_t)(p))
#define PTR2IV(p)   ((IV)(intptr_t)(p))
#define PTR2NV(p)   ((NV)PTR2UV(p))
#define INT2PTR(t, i) ((t)(uintptr_t)(i))

/* Perl_newXS_deffile — register an XS sub with no file-name arg. Real
 * Perl inserts into its stash so $pkg->method finds the XS entrypoint.
 * Perla's method dispatch goes through perla_code_set; register there
 * so boot_XYZ() wiring works. */
#ifndef Perl_newXS_deffile
static inline CV* Perl_newXS_deffile(pTHX_ const char *name, XSPROTO(func)) {
    (void)func;
    /* Register under the passed name (e.g. "MyMath::add"). */
    const char *colons = name ? strstr(name, "::") : NULL;
    if (colons) {
        size_t pkg_len = (size_t)(colons - name);
        char pkg[256];
        if (pkg_len >= sizeof(pkg)) pkg_len = sizeof(pkg) - 1;
        memcpy(pkg, name, pkg_len);
        pkg[pkg_len] = '\0';
        const char *sub = colons + 2;
        /* Create an XSUB-marked CPOINTER. perla_call_code detects the
         * "XSUB" struct_name and routes through perla_xs_invoke, which
         * adapts Perla's (args-array) calling convention to XS's stack
         * convention. Without the marker, perla_call_code would try to
         * call `func(args)` directly, which is the wrong ABI. */
        extern void perla_code_set(const char *pkg, const char *name, StradaValue *code);
        extern StradaValue *perla_xsub_new(void (*fn)(void*));
        StradaValue *cv = perla_xsub_new((void (*)(void*))func);
        perla_code_set(pkg, sub, cv);
    }
    return NULL;
}
#endif
#define newXS(name, func, file) Perl_newXS(name, func, file)
#define XS(name) void name(CV* cv)
#define XS_INTERNAL(name) static XS(name)
#define XS_EXTERNAL(name) XS(name)

/* Boot/init macros */
#define XS_VERSION NULL
#define XS_APIVERSION_BOOTCHECK do {} while(0)
#define XS_VERSION_BOOTCHECK do {} while(0)

#define dMY_CXT    /* no thread-local storage */
#define MY_CXT_INIT do {} while(0)

/* Items macro for XS argument count */
#define G_SCALAR   0
#define G_ARRAY    1
#define G_VOID     2
#define G_DISCARD  4
#define G_EVAL     8
#define G_NOARGS   16
#define G_KEEPERR  32

/* HV action flags */
#define HV_FETCH_ISSTORE 0x02

/* Perl phases */
#define PERL_PHASE_CONSTRUCT 0
#define PERL_PHASE_START     1
#define PERL_PHASE_CHECK     2
#define PERL_PHASE_INIT      3
#define PERL_PHASE_RUN       4
#define PERL_PHASE_END       5
#define PERL_PHASE_DESTRUCT  6

/* ============================================================
 * Phase-2 additions — broader XS compat surface
 *
 * Everything below was added to expand the number of CPAN XS
 * modules that compile cleanly against Perla's perl.h shim.
 * Stubs are marked STUB or NO-OP; real implementations route
 * through the Strada runtime or Perla's stash.
 * ============================================================ */

/* ---------- Null aliases ---------- */
#define Nullsv  ((SV*)NULL)
#define Nullav  ((AV*)NULL)
#define Nullhv  ((HV*)NULL)
#define Nullch  ((char*)NULL)
#define Nullcv  ((CV*)NULL)
#define Nullgv  ((GV*)NULL)
#define Nullhek ((void*)NULL)

/* ---------- Scratch globals ---------- */
/* PL_na — scratch STRLEN used by things that don't care about length.
 * Real Perl declares it as a thread-local; we can share. */
static STRLEN perla_na;
#define PL_na perla_na
static const char *const perla_no_modify = "Modification of a read-only value attempted";
#define PL_no_modify perla_no_modify

/* ---------- SV setters (bit-level mutation) ---------- */
/* Real Perl stores IV/NV/PV in separate SV body slots. We only have
 * one `value` union, so these change both the type and the stored
 * value. Callers expect "after SvIV_set(sv, x), SvIV(sv) == x" and
 * that's what they get. */
static inline void Perl_sv_iv_set(SV *sv, IV i) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_STR && sv->value.pv) { free(sv->value.pv); sv->value.pv = NULL; }
    sv->type = STRADA_INT;
    sv->value.iv = (int64_t)i;
}
static inline void Perl_sv_nv_set(SV *sv, NV n) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_STR && sv->value.pv) { free(sv->value.pv); sv->value.pv = NULL; }
    sv->type = STRADA_NUM;
    sv->value.nv = n;
}
static inline void Perl_sv_pv_set(SV *sv, char *s) {
    if (!sv || STRADA_IS_TAGGED_INT(sv)) return;
    if (sv->type == STRADA_STR && sv->value.pv) free(sv->value.pv);
    sv->type = STRADA_STR;
    sv->value.pv = s;  /* XS takes ownership */
    sv->struct_size = s ? strlen(s) : 0;
}
static inline void Perl_sv_cur_set(SV *sv, STRLEN len) {
    if (!sv || STRADA_IS_TAGGED_INT(sv) || sv->type != STRADA_STR) return;
    sv->struct_size = len;
    if (sv->value.pv) sv->value.pv[len] = '\0';
}
#define SvIV_set(sv, i)   Perl_sv_iv_set(sv, i)
#define SvUV_set(sv, u)   Perl_sv_iv_set(sv, (IV)(u))
#define SvNV_set(sv, n)   Perl_sv_nv_set(sv, n)
#define SvPV_set(sv, s)   Perl_sv_pv_set(sv, s)
#define SvCUR_set(sv, l)  Perl_sv_cur_set(sv, l)
#define SvLEN(sv)         SvCUR(sv)       /* no separate allocated length */
#define SvLEN_set(sv, l)  Perl_sv_cur_set(sv, l)
#define SvEND(sv)         (SvPVX(sv) + SvCUR(sv))

/* Raw-access macros (no magic). Perla has no magic, so these are the
 * same as the magic-aware variants. */
#define SvIVX(sv)         SvIV(sv)
#define SvNVX(sv)         SvNV(sv)
#define SvUVX(sv)         SvUV(sv)
#define SvIV_nomg(sv)     SvIV(sv)
#define SvUV_nomg(sv)     SvUV(sv)
#define SvNV_nomg(sv)     SvNV(sv)
#define SvPV_nomg(sv,l)   SvPV(sv,l)
#define SvPV_nomg_nolen(sv) SvPV_nolen(sv)
#define SvTRUE_nomg(sv)   SvTRUE(sv)

/* Force-PV variants — Perla has no upgrade machinery; calling SvPV is
 * enough because strada_to_str coerces. */
#define SvPV_force(sv, l)         SvPV(sv, l)
#define SvPV_force_nolen(sv)      SvPV_nolen(sv)
#define SvPV_force_nomg(sv, l)    SvPV(sv, l)
#define SvPVbyte_nolen(sv)        SvPV_nolen(sv)
#define SvPVbyte_force(sv, l)     SvPV(sv, l)
#define SvPVutf8(sv, l)           SvPV(sv, l)
#define SvPVutf8_nolen(sv)        SvPV_nolen(sv)
#define SvPV_mutable(sv, l)       SvPV(sv, l)
#define SvPV_const(sv, l)         ((const char*)SvPV(sv, l))
#define SvPV_nolen_const(sv)      ((const char*)SvPV_nolen(sv))
#define SvIsUV(sv)                (SvIOK(sv))
#define SvIOK_UV(sv)              (SvIOK(sv))
#define SvIOK_notUV(sv)           (SvIOK(sv))
#define SvIOK_on(sv)              do {} while(0)
#define SvNOK_on(sv)              do {} while(0)
#define SvPOK_on(sv)              do {} while(0)
#define SvIOK_off(sv)             do {} while(0)
#define SvNOK_off(sv)             do {} while(0)
#define SvPOK_off(sv)             do {} while(0)
#define SvROK_on(sv)              do {} while(0)
#define SvROK_off(sv)             do {} while(0)
#define SvOK_off(sv)              do { if (sv && !STRADA_IS_TAGGED_INT(sv)) { sv->type = STRADA_UNDEF; } } while(0)
#define SvSETMAGIC(sv)            do {} while(0)   /* no magic here */
#define SvGETMAGIC(sv)            do {} while(0)
#define SvNIOK(sv)                (SvIOK(sv) || SvNOK(sv))

/* ---------- Mutation+magic aliases ---------- */
#define sv_setpv_mg(sv, s)        Perl_sv_setpv(sv, s)
#define sv_setpvn_mg(sv, s, n)    Perl_sv_setpvn(sv, s, n)
#define sv_setsv_mg(d, s)         Perl_sv_setsv_flags(d, s, 0)
#define sv_catpv_mg(sv, s)        Perl_sv_catpv(sv, s)
#define sv_catsv_mg(d, s)         Perl_sv_catsv_flags(d, s, 0)
#define sv_setuv_mg(sv, u)        Perl_sv_setiv(sv, (IV)(u))
#define sv_catpvn(sv, s, n)       Perl_sv_catpvn_flags(sv, s, n, 0)
#define sv_catpvn_mg(sv, s, n)    Perl_sv_catpvn_flags(sv, s, n, 0)
#define sv_setref_pv(sv, cn, ptr) sv_setref_pv_real(sv, cn, ptr)
#define sv_setref_iv(sv, cn, iv)  sv_setref_iv_real(sv, cn, iv)
#define sv_setref_uv(sv, cn, uv)  sv_setref_iv_real(sv, cn, (IV)(uv))
#define sv_setref_nv(sv, cn, nv)  sv_setref_nv_real(sv, cn, nv)
#define sv_setref_pvn(sv, cn, s, n) sv_setref_pvn_real(sv, cn, s, n)
#define sv_bless(sv, stash)       Perl_sv_bless(sv, stash)
#define newSVsv_flags(s, f)       Perl_newSVsv_flags(s, f)
#define sv_newref(sv)             SvREFCNT_inc(sv)

/* sv_setref_* — set sv to a blessed reference to a C pointer/value.
 * Real Perl wraps the C value in an IV-holding SV then blesses the ref
 * into class `classname`. We do the same using Strada's ref + meta. */
static inline SV* sv_setref_iv_real(SV *rv, const char *classname, IV iv) {
    SV *inner = strada_new_int((int64_t)iv);
    SV *ref = strada_ref_create(inner);
    if (classname && ref && !STRADA_IS_TAGGED_INT(ref)) {
        strada_bless(ref, classname);
    }
    if (rv && !STRADA_IS_TAGGED_INT(rv)) {
        if (rv->type == STRADA_STR && rv->value.pv) free(rv->value.pv);
        rv->type = STRADA_REF;
        rv->value.rv = ref;
        if (classname) strada_bless(rv, classname);
    }
    return rv;
}
static inline SV* sv_setref_nv_real(SV *rv, const char *classname, NV nv) {
    SV *inner = strada_new_num(nv);
    SV *ref = strada_ref_create(inner);
    if (classname && ref && !STRADA_IS_TAGGED_INT(ref)) {
        strada_bless(ref, classname);
    }
    if (rv && !STRADA_IS_TAGGED_INT(rv)) {
        if (rv->type == STRADA_STR && rv->value.pv) free(rv->value.pv);
        rv->type = STRADA_REF;
        rv->value.rv = ref;
        if (classname) strada_bless(rv, classname);
    }
    return rv;
}
static inline SV* sv_setref_pv_real(SV *rv, const char *classname, void *ptr) {
    return sv_setref_iv_real(rv, classname, (IV)(intptr_t)ptr);
}
static inline SV* sv_setref_pvn_real(SV *rv, const char *classname, const char *s, STRLEN n) {
    SV *inner = strada_new_str_len(s, n);
    SV *ref = strada_ref_create(inner);
    if (classname && ref && !STRADA_IS_TAGGED_INT(ref)) {
        strada_bless(ref, classname);
    }
    if (rv && !STRADA_IS_TAGGED_INT(rv)) {
        if (rv->type == STRADA_STR && rv->value.pv) free(rv->value.pv);
        rv->type = STRADA_REF;
        rv->value.rv = ref;
        if (classname) strada_bless(rv, classname);
    }
    return rv;
}

/* boolSV — canonical true/false SV */
#define boolSV(b)  ((b) ? &PL_sv_yes : &PL_sv_no)

/* ---------- AV extras ---------- */
/* AvARRAY in real Perl is a direct SV** pointer; for Perla we expose
 * the raw elements + head offset (the array may have been shifted).
 * Note: not all operations are safe when head != 0; prefer av_fetch. */
#define AvARRAY(av)       ((av) ? ((SV**)((av)->elements + (av)->head)) : (SV**)NULL)
#define AvFILL(av)        Perl_av_len(av)
#define AvFILLp(av)       Perl_av_len(av)
#define AvLEN(av)         ((av) ? (I32)(av)->capacity : 0)
#define av_top_index(av)  Perl_av_len(av)
#define av_tindex(av)     Perl_av_len(av)
#define av_count(av)      ((av) ? (I32)(av)->size : 0)
static inline void Perl_av_clear(AV *av)  {
    if (!av) return;
    while (av->size > 0) {
        StradaValue *v = av->elements[av->head + av->size - 1];
        av->size--;
        strada_decref(v);
    }
}
static inline void Perl_av_undef(AV *av)  { Perl_av_clear(av); }
static inline void Perl_av_unshift(AV *av, I32 num) {
    /* Inserts `num` undef slots at the front. Used by XS rarely. */
    if (!av) return;
    for (I32 i = 0; i < num; i++) {
        strada_array_unshift(av, strada_new_undef());
    }
}
#define av_clear(av)     Perl_av_clear(av)
#define av_undef(av)     Perl_av_undef(av)
#define av_unshift(av,n) Perl_av_unshift(av,n)
#define newAV()          ((AV*)strada_new_array())
#define av_exists(av,i)  ((av) && (i) >= 0 && (I32)(i) < (I32)(av)->size)

/* ---------- HV extras ---------- */
#define newHV()                ((HV*)strada_new_hash())
#define hv_stores(hv, key, val) \
    Perl_hv_common_key_len(hv, "" key "", (I32)(sizeof(key)-1), 0x02, val, 0)
#define hv_fetchs(hv, key, lval) \
    Perl_hv_common_key_len(hv, "" key "", (I32)(sizeof(key)-1), 0, NULL, 0)
#define hv_deletes(hv, key, flags) \
    hv_delete(hv, "" key "", (I32)(sizeof(key)-1), flags)
#define hv_existss(hv, key) \
    hv_exists(hv, "" key "", (I32)(sizeof(key)-1))
static inline void Perl_hv_undef(HV *hv) { (void)hv; /* STUB */ }
#define hv_undef(hv)   Perl_hv_undef(hv)

/* ---------- SV boilerplate ---------- */
#define sv_setiv(sv, i)        Perl_sv_setiv(sv, i)
#define sv_setuv(sv, u)        Perl_sv_setuv(sv, u)
#define sv_setnv(sv, n)        Perl_sv_setnv(sv, n)
#define sv_setpv(sv, s)        Perl_sv_setpv(sv, s)
#define sv_setpvn(sv, s, n)    Perl_sv_setpvn(sv, s, n)
#define sv_catpv(sv, s)        Perl_sv_catpv(sv, s)
#define sv_catsv(d, s)         Perl_sv_catsv_flags(d, s, 0)
#define sv_inc(sv)             Perl_sv_inc(sv)
#define sv_isobject(sv)        Perl_sv_isobject(sv)
#define sv_derived_from(sv, n) Perl_sv_derived_from(sv, n)
#define sv_reftype(sv, ob)     Perl_sv_reftype(sv, ob)
#define sv_force_normal(sv)    Perl_sv_force_normal_flags(sv, 0)
#define sv_dump(sv)            Perl_sv_dump(sv)
#define sv_grow(sv, l)         Perl_sv_grow(sv, l)
#define sv_rvweaken(sv)        Perl_sv_rvweaken(sv)
#define sv_magic(sv, o, h, n, nl) Perl_sv_magic(sv, o, h, n, nl)
#define sv_unmagic(sv, t)      Perl_sv_unmagic(sv, t)
#define sv_upgrade(sv, t)      Perl_sv_upgrade(sv, t)
#define sv_insert(sv, o, l, s, sl) Perl_sv_insert_flags(sv, o, l, s, sl, 0)
#define sv_2iv(sv)             SvIV(sv)
#define sv_2uv(sv)             SvUV(sv)
#define sv_2nv(sv)             SvNV(sv)
#define sv_2pv(sv, l)          SvPV(sv, l)
#define sv_2pv_nolen(sv)       SvPV_nolen(sv)
#define sv_2bool(sv)           SvTRUE(sv)
#define sv_true(sv)            SvTRUE(sv)
#define sv_tainted(sv)         Perl_sv_tainted(sv)
#define sv_utf8_decode(sv)     Perl_sv_utf8_decode(sv)
#define sv_2mortal(sv)         Perl_sv_2mortal(sv)

/* ---------- _mg variants of creators ---------- */
#define newSViv_mg(i)   Perl_newSViv(i)
#define newSVuv_mg(u)   Perl_newSVuv(u)
#define newSVnv_mg(n)   Perl_newSVnv(n)
#define newSVpv_mg(s,l) Perl_newSVpv(s,l)
#define newSVpvn_mg(s,l) Perl_newSVpvn(s,l)
#define newSVpvs(literal)      Perl_newSVpvn("" literal "", sizeof(literal)-1)
#define newSVpvs_share(literal) Perl_newSVpvn("" literal "", sizeof(literal)-1)
#define newSVpvs_flags(literal, f) Perl_newSVpvn("" literal "", sizeof(literal)-1)
#define newSVpvf               Perl_newSVpvf
#define sv_setpvs(sv, literal) Perl_sv_setpvn(sv, "" literal "", sizeof(literal)-1)
#define sv_catpvs(sv, literal) Perl_sv_catpvn_flags(sv, "" literal "", sizeof(literal)-1, 0)

/* ---------- string compare macros ---------- */
#define strEQ(a,b)         (strcmp(a,b) == 0)
#define strNE(a,b)         (strcmp(a,b) != 0)
#define strLT(a,b)         (strcmp(a,b) <  0)
#define strGT(a,b)         (strcmp(a,b) >  0)
#define strLE(a,b)         (strcmp(a,b) <= 0)
#define strGE(a,b)         (strcmp(a,b) >= 0)
#define strnEQ(a,b,n)      (strncmp(a,b,n) == 0)
#define strnNE(a,b,n)      (strncmp(a,b,n) != 0)
#define memEQ(a,b,n)       (memcmp(a,b,n) == 0)
#define memNE(a,b,n)       (memcmp(a,b,n) != 0)
#define memEQs(s, slen, literal) \
    ((slen) == sizeof(literal)-1 && memcmp(s, "" literal "", sizeof(literal)-1) == 0)
#define memNEs(s, slen, literal) (!memEQs(s, slen, literal))

/* ---------- char class macros (ASCII-only) ---------- */
#define isSPACE(c)   (isspace((unsigned char)(c)))
#define isDIGIT(c)   (isdigit((unsigned char)(c)))
#define isALPHA(c)   (isalpha((unsigned char)(c)))
#define isALNUM(c)   (isalnum((unsigned char)(c)))
#define isWORDCHAR(c) (isalnum((unsigned char)(c)) || (c) == '_')
#define isUPPER(c)   (isupper((unsigned char)(c)))
#define isLOWER(c)   (islower((unsigned char)(c)))
#define isPRINT(c)   (isprint((unsigned char)(c)))
#define isCNTRL(c)   (iscntrl((unsigned char)(c)))
#define isGRAPH(c)   (isgraph((unsigned char)(c)))
#define isPUNCT(c)   (ispunct((unsigned char)(c)))
#define isXDIGIT(c)  (isxdigit((unsigned char)(c)))
#define toUPPER(c)   ((char)toupper((unsigned char)(c)))
#define toLOWER(c)   ((char)tolower((unsigned char)(c)))
#define toFOLD(c)    toLOWER(c)
#define isSPACE_A(c) isSPACE(c)
#define isDIGIT_A(c) isDIGIT(c)
#define isALPHA_A(c) isALPHA(c)
#define isALNUM_A(c) isALNUM(c)
#define isUPPER_A(c) isUPPER(c)
#define isLOWER_A(c) isLOWER(c)
#define toUPPER_A(c) toUPPER(c)
#define toLOWER_A(c) toLOWER(c)

/* Need <ctype.h> for those — include it */
#include <ctype.h>

/* ---------- Perl_form — sprintf into scratch buffer ---------- */
/* Real Perl returns a mortal string in its own buffer. We use a
 * per-thread rotating buffer (same 16-slot trick as fetch_slot). */
#define PERLA_FORM_POOL_SIZE 8
#define PERLA_FORM_BUF_SIZE 512
static char perla_form_pool[PERLA_FORM_POOL_SIZE][PERLA_FORM_BUF_SIZE];
static int perla_form_pool_idx = 0;
static inline char* Perl_form_nocontext(const char *fmt, ...) {
    va_list ap;
    perla_form_pool_idx = (perla_form_pool_idx + 1) & (PERLA_FORM_POOL_SIZE - 1);
    char *buf = perla_form_pool[perla_form_pool_idx];
    va_start(ap, fmt);
    vsnprintf(buf, PERLA_FORM_BUF_SIZE, fmt, ap);
    va_end(ap);
    return buf;
}
#define Perl_form   Perl_form_nocontext
#define form        Perl_form_nocontext
#define Perl_mess   Perl_form_nocontext

/* ---------- get_sv/get_av/get_hv/get_cv — real lookups ---------- */
/* These route through Perla's stash instead of returning NULL. They
 * parse "Pkg::name" and dispatch to perla_scalar_get / _array_get /
 * _hash_get. */
static inline void perla_split_fullname(const char *name, char *pkg, size_t pkg_sz, const char **sub_out) {
    const char *last = name;
    const char *p = name;
    while (p && *p) {
        if (p[0] == ':' && p[1] == ':') {
            last = p;
            p += 2;
        } else {
            p++;
        }
    }
    if (last == name) {
        /* no :: — assume main */
        strncpy(pkg, "main", pkg_sz - 1);
        pkg[pkg_sz - 1] = '\0';
        *sub_out = name;
    } else {
        size_t n = (size_t)(last - name);
        if (n >= pkg_sz) n = pkg_sz - 1;
        memcpy(pkg, name, n);
        pkg[n] = '\0';
        *sub_out = last + 2;
    }
}

static inline SV* Perl_get_sv_real(const char *name, int flags) {
    if (!name) return NULL;
    char pkg[256];
    const char *sub;
    perla_split_fullname(name, pkg, sizeof(pkg), &sub);
    SV *v = perla_scalar_get(pkg, sub);
    if (!v && (flags & 0x02)) {  /* GV_ADD */
        v = strada_new_undef();
        perla_scalar_set(pkg, sub, v);
    }
    return v ? v : strada_new_undef();
}
#undef Perl_get_sv
#define Perl_get_sv(n, f)  Perl_get_sv_real(n, f)
#define get_sv(n, f)       Perl_get_sv_real(n, f)

static inline AV* Perl_get_av_real(const char *name, int flags) {
    if (!name) return NULL;
    char pkg[256];
    const char *sub;
    perla_split_fullname(name, pkg, sizeof(pkg), &sub);
    SV *v = perla_array_get(pkg, sub);
    if (!v || STRADA_IS_TAGGED_INT(v) || v->type != STRADA_ARRAY) return NULL;
    return (AV*)v->value.av;
}
#define Perl_get_av(n, f)  Perl_get_av_real(n, f)
#define get_av(n, f)       Perl_get_av_real(n, f)

static inline HV* Perl_get_hv_real(const char *name, int flags) {
    if (!name) return NULL;
    char pkg[256];
    const char *sub;
    perla_split_fullname(name, pkg, sizeof(pkg), &sub);
    SV *v = perla_hash_get(pkg, sub);
    if (!v || STRADA_IS_TAGGED_INT(v) || v->type != STRADA_HASH) return NULL;
    return (HV*)v->value.hv;
}
#define Perl_get_hv(n, f)  Perl_get_hv_real(n, f)
#define get_hv(n, f)       Perl_get_hv_real(n, f)

/* get_cv — Perla's code table stores callables. Return as SV* since
 * real Perl's CV* is an opaque pointer; XS only uses it to pass to
 * call_sv anyway. */
extern StradaValue *perla_code_get(const char *pkg, const char *name);
static inline CV* Perl_get_cv_real(const char *name, int flags) {
    if (!name) return NULL;
    char pkg[256];
    const char *sub;
    perla_split_fullname(name, pkg, sizeof(pkg), &sub);
    StradaValue *code = perla_code_get(pkg, sub);
    return (CV*)code;
}
#undef Perl_get_cv
#define Perl_get_cv(n, f)  Perl_get_cv_real(n, f)
#define get_cv(n, f)       Perl_get_cv_real(n, f)
#define get_cvn_flags(n, l, f) Perl_get_cv_real(n, f)

/* ---------- call_sv / call_pv / call_method — real invocation ---------- */
/* These pop args off perla_stack (between the mark and sp), build an
 * array, invoke, push the result, and return the count pushed.
 *
 * Semantics match Perl's call_sv/call_method well enough for typical
 * XS callbacks: flags G_SCALAR forces one return; G_ARRAY returns
 * however many; G_DISCARD ignores the return; G_EVAL is best-effort
 * (Perla's try/catch goes through strada_die). */

static inline I32 perla_xs_invoke(StradaValue *code_or_obj, const char *method, I32 flags) {
    dSP;
    /* Pop args from stack: everything from mark+1 up to sp */
    I32 mark = POPMARK;
    I32 nargs = (I32)((sp - perla_stack) - mark);
    StradaValue *args = (StradaValue*)strada_new_array();
    for (I32 i = 0; i < nargs; i++) {
        SV *a = perla_stack[mark + 1 + i];
        if (a) strada_incref(a);
        strada_array_push((StradaArray*)args->value.av, a);
    }
    /* Reset sp to mark */
    perla_sp = perla_stack + mark;
    sp = perla_sp;

    StradaValue *ret = NULL;
    StradaArray *args_av = args->value.av;
    if (method) {
        /* call_method: first arg is the invocant */
        if (args_av->size > 0) {
            StradaValue *self = strada_array_get(args_av, 0);
            StradaValue *method_args = (StradaValue*)strada_new_array();
            for (size_t i = 1; i < args_av->size; i++) {
                StradaValue *arg_i = strada_array_get(args_av, (int64_t)i);
                if (arg_i) strada_incref(arg_i);
                strada_array_push((StradaArray*)method_args->value.av, arg_i);
            }
            ret = perla_method_dispatch(self, method, method_args);
            strada_decref(method_args);
        }
    } else if (code_or_obj) {
        ret = perla_call_code(code_or_obj, args);
    }
    strada_decref(args);

    if (flags & G_DISCARD) {
        if (ret) strada_decref(ret);
        PUTBACK;
        return 0;
    }
    if (!ret) {
        if (flags & G_SCALAR) {
            XPUSHs(strada_new_undef());
            PUTBACK;
            return 1;
        }
        PUTBACK;
        return 0;
    }
    /* List context: if result is an array, flatten it. */
    if ((flags & G_ARRAY) && !STRADA_IS_TAGGED_INT(ret) && ret->type == STRADA_ARRAY) {
        StradaArray *rav = ret->value.av;
        I32 pushed = 0;
        for (size_t i = 0; i < rav->size; i++) {
            StradaValue *e = strada_array_get(rav, (int64_t)i);
            if (e) strada_incref(e);
            XPUSHs(e);
            pushed++;
        }
        strada_decref(ret);
        PUTBACK;
        return pushed;
    }
    XPUSHs(ret);
    PUTBACK;
    return 1;
}

static inline I32 Perl_call_sv_real(SV *sv, I32 flags) {
    return perla_xs_invoke(sv, NULL, flags);
}
#undef Perl_call_sv
#define Perl_call_sv(sv, f)      Perl_call_sv_real(sv, f)
#define call_sv(sv, f)           Perl_call_sv_real(sv, f)

static inline I32 Perl_call_method_real(const char *method, I32 flags) {
    return perla_xs_invoke(NULL, method, flags);
}
#undef Perl_call_method
#define Perl_call_method(m, f)   Perl_call_method_real(m, f)
#define call_method(m, f)        Perl_call_method_real(m, f)

static inline I32 Perl_call_pv_real(const char *name, I32 flags) {
    CV *cv = Perl_get_cv_real(name, 0);
    if (!cv) return 0;
    return Perl_call_sv_real((SV*)cv, flags);
}
#define Perl_call_pv(n, f)       Perl_call_pv_real(n, f)
#define call_pv(n, f)            Perl_call_pv_real(n, f)
#define call_argv(n, f, argv)    Perl_call_pv_real(n, f)  /* ignores argv */

/* eval_sv / eval_pv — routed through Perla's eval path. perla_eval_string
 * takes (StradaValue *code_sv, const char *current_pkg) per perla_stash.h. */
static inline I32 Perl_eval_sv(SV *sv, I32 flags) {
    return Perl_call_sv_real(sv, flags | G_EVAL);
}
#define eval_sv(sv, f)   Perl_eval_sv(sv, f)
static inline SV* Perl_eval_pv(const char *code, I32 croak_on_error) {
    StradaValue *code_sv = strada_new_str(code ? code : "");
    StradaValue *r = perla_eval_string(code_sv, "main");
    strada_decref(code_sv);
    return r ? r : strada_new_undef();
}
#define eval_pv(code, c) Perl_eval_pv(code, c)

/* ---------- Perl_newXS — actually register ---------- */
#undef Perl_newXS
static inline CV* Perl_newXS_real(const char *name, void (*func)(CV*), const char *file) {
    if (!name || !func) return NULL;
    char pkg[256];
    const char *sub;
    perla_split_fullname(name, pkg, sizeof(pkg), &sub);
    StradaValue *cv = strada_new_int((int64_t)(intptr_t)func);
    perla_code_set(pkg, sub, cv);
    return NULL;
}
#define Perl_newXS(name, func, file)  Perl_newXS_real(name, func, file)
#undef Perl_newXS_flags
static inline CV* Perl_newXS_flags_real(const char *name, void (*func)(CV*),
                                         const char *file, const char *proto, int flags) {
    return Perl_newXS_real(name, func, file);
}
#define Perl_newXS_flags(n, f, file, p, fl)  Perl_newXS_flags_real(n, f, file, p, fl)
#define newXSproto(name, func, file, proto)  Perl_newXS_real(name, func, file)
#define newXSproto_named(name, func, file, proto) Perl_newXS_real(name, func, file)

/* ---------- gv_stashpv/gv_stashsv — return a marker HV ---------- */
/* Perla's stash is per-package, keyed by name. We return a pointer
 * that's unique to the package name; real Perl XS only uses the
 * returned HV* for sv_bless + gv_fetchmethod, which route through
 * pkg name anyway. Store a name:HV mapping. */
static inline HV* perla_stash_for_pkg(const char *name) {
    /* Return a canonical HV per package. Use a small global hash of
     * string→StradaHash to guarantee pointer identity across calls. */
    static StradaHash *stash_of_stashes = NULL;
    if (!stash_of_stashes) stash_of_stashes = strada_new_hash();
    StradaValue *existing = strada_hash_get(stash_of_stashes, name);
    if (existing && !STRADA_IS_TAGGED_INT(existing) && existing->type == STRADA_HASH) {
        /* Make sure the blessed_package name is set for sv_bless. */
        return (HV*)existing->value.hv;
    }
    StradaValue *fresh = strada_new_hash();
    /* Tag it with the package name via meta so sv_bless can read it. */
    strada_bless(fresh, name);
    strada_hash_set(stash_of_stashes, name, fresh);
    return (HV*)fresh->value.hv;
}
#undef Perl_gv_stashpv
#define Perl_gv_stashpv(n, f)   perla_stash_for_pkg(n)
#define gv_stashpv(n, f)        perla_stash_for_pkg(n)
#define gv_stashpvn(n, l, f)    perla_stash_for_pkg(n)  /* len ignored */
#define gv_stashpvs(literal, f) perla_stash_for_pkg("" literal "")

/* ---------- Perl_croak_sv/Perl_vcroak/warn family ---------- */
static inline void Perl_vcroak(const char *fmt, va_list *ap) {
    char buf[4096];
    vsnprintf(buf, sizeof(buf), fmt, *ap);
    strada_die("%s", buf);
}
static inline void Perl_warner(U32 err, const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s", buf);
}
static inline void Perl_ck_warner(U32 err, const char *fmt, ...) {
    char buf[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "%s", buf);
}
#define ckWARN(category)   0
#define ckWARN2(c1, c2)    0

/* ---------- POPi/POPn/POPp/POPs variants ---------- */
#define POPi   ((IV)SvIV(*sp--))
#define POPu   ((UV)SvUV(*sp--))
#define POPn   ((NV)SvNV(*sp--))
#define POPl   POPi
#define POPpx  SvPV_nolen(*sp--)
#define POPp   POPpx
#define POPpbytex POPpx

/* ---------- SAVE* stubs — Perla has no pad/scope machinery ---------- */
#define SAVEI32(v)      do {} while(0)
#define SAVEINT(v)      do {} while(0)
#define SAVELONG(v)     do {} while(0)
#define SAVEIV(v)       do {} while(0)
#define SAVESPTR(v)     do {} while(0)
#define SAVEPPTR(v)     do {} while(0)
#define SAVEHPTR(v)     do {} while(0)
#define SAVEFREESV(sv)  do { if (sv) strada_decref(sv); } while(0)
#define SAVEFREEPV(pv)  do { if (pv) free(pv); } while(0)
#define SAVEMORTALIZESV(sv) Perl_sv_2mortal(sv)
#define SAVEDESTRUCTOR(fn, p) do {} while(0)
#define SAVEDESTRUCTOR_X(fn, p) do {} while(0)
#define SAVECOPFILE(op) do {} while(0)
#define SAVECOPLINE(op) do {} while(0)
#define SAVEVPTR(v)     do {} while(0)

/* ---------- Op/Cop stubs ---------- */
#define OP_NAME(op)   "unknown"
#define OP_DESC(op)   "unknown"
#define CopLINE(cop)  0
#define CopFILE(cop)  ""
#define CopSTASH(cop) NULL
#define CopSTASHPV(cop) "main"
#define CopFILEGV(cop) NULL

/* ---------- gv helpers ---------- */
#define gv_fetchpv(name, flags, type)       Perl_gv_fetchpv(name, flags, type)
#define gv_fetchpvn_flags(n, l, f, t)        Perl_gv_fetchpv(n, f, t)
#define gv_fetchmethod(stash, method)        NULL
#define gv_fetchmethod_autoload(s, m, a)     Perl_gv_fetchmethod_autoload(s, m, a)
#define gv_fullname(sv, gv)                  do {} while(0)
#define gv_efullname(sv, gv)                 do {} while(0)
/* GvSV(gv) — XS modules use this to read/write the typeglob's scalar
 * slot. perla only has one real GV — PL_defgv (the $_ glob) — and
 * everywhere else GvSV would be NULL. We always dereference into
 * perla_dollar_underscore so XS code that passes any value here gets
 * perla's $_. (The macro is also an lvalue, supporting `GvSV(gv) = sv`
 * in addition to the more common `sv_setsv(GvSV(gv), val)`.) */
#define GvSV(gv)        (*perla_defgv_storage.sv_ptr)
#define GvAV(gv)        ((AV*)NULL)
#define GvHV(gv)        ((HV*)NULL)
#define GvCV(gv)        ((CV*)NULL)
#define GvGP(gv)        NULL
#define isGV(sv)        0
#define isGV_with_GP(sv) 0
#define SvTYPE(sv)      (STRADA_IS_TAGGED_INT(sv) ? SVt_IV : ((sv) ? (sv)->type : SVt_NULL))

/* ---------- STMT_START / STMT_END — do-while wrappers ---------- */
#define STMT_START do
#define STMT_END   while (0)

/* ---------- Dev-null assertions ---------- */
#define PERL_ARGS_ASSERT_CROAK                do {} while(0)
#define PERL_ARGS_ASSERT_NEWSV                do {} while(0)
#define assert(x)                             ((void)0)

/* ---------- Misc small bits ---------- */
#define my_snprintf   snprintf
#define my_vsnprintf  vsnprintf
#define PERL_UNUSED_RESULT(x) ((void)(x))
#define NOOP ((void)0)
#define dNOOP ((void)0)

#endif /* PERLA_PERL_COMPAT_H */
