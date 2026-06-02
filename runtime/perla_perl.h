/*
 * perla_perl.h — Standalone Perl C API compatibility header
 *
 * Defines Perl's core types, structs, macros and constants WITHOUT
 * requiring a Perl installation. Matches Perl 5.42 x86_64-linux layout.
 *
 * This header + perla_perl_api.c + perla_perl_runtime.c allows compiling
 * and linking XS modules (DBI, DBD::mysql, etc.) against Perla.
 */

#ifndef PERLA_PERL_H
#define PERLA_PERL_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>

/* ============================================================
 * Base integer types (matches Perl 5.42 on x86_64-linux)
 * ============================================================ */

typedef int64_t   IV;
typedef uint64_t  UV;
typedef double    NV;
typedef int32_t   I32;
typedef uint32_t  U32;
typedef int16_t   I16;
typedef uint16_t  U16;
typedef uint8_t   U8;
typedef size_t    STRLEN;
typedef size_t    Size_t;
typedef ssize_t   SSize_t;
typedef SSize_t   Stack_off_t;
typedef U32       cv_flags_t;
typedef FILE      PerlIO;

/* Forward declarations */
typedef struct sv    SV;
typedef struct av    AV;
typedef struct hv    HV;
typedef struct cv    CV;
typedef struct gv    GV;
typedef struct io    IO;
typedef struct op    OP;
typedef struct hek   HEK;
typedef struct he    HE;
typedef struct magic MAGIC;
typedef struct mgvtbl MGVTBL;
typedef struct cop   COP;
typedef struct gp    GP;
typedef void         PADLIST;
typedef void         PERL_CONTEXT;
typedef void         PERL_SI;

/* ============================================================
 * SV type enum
 * ============================================================ */

typedef enum {
    SVt_NULL = 0,
    SVt_IV = 1,
    SVt_NV = 2,
    SVt_PV = 3,
    SVt_INVLIST = 4,
    SVt_PVIV = 5,
    SVt_PVNV = 6,
    SVt_PVMG = 7,
    SVt_REGEXP = 8,
    SVt_PVGV = 9,
    SVt_PVLV = 10,
    SVt_PVAV = 11,
    SVt_PVHV = 12,
    SVt_PVCV = 13,
    SVt_PVFM = 14,
    SVt_PVIO = 15,
    SVt_PVOBJ = 16,
    SVt_LAST = 17
} svtype;

/* ============================================================
 * SV flags
 * ============================================================ */

#define SVt_MASK        0x1f
#define SVf_IOK         0x00000100
#define SVf_NOK         0x00000200
#define SVf_POK         0x00000400
#define SVf_ROK         0x00000800
#define SVp_IOK         0x00001000
#define SVp_NOK         0x00002000
#define SVp_POK         0x00004000
#define SVp_SCREAM      0x00008000
#define SVf_PROTECT     0x00010000
#define SVs_PADTMP      0x00020000
#define SVs_PADSTALE    0x00040000
#define SVs_TEMP        0x00080000
#define SVs_OBJECT      0x00100000
#define SVs_GMG         0x00200000
#define SVs_SMG         0x00400000
#define SVs_RMG         0x00800000
#define SVf_FAKE        0x01000000
#define SVf_OOK         0x02000000
#define SVf_BREAK       0x04000000
#define SVf_READONLY    0x08000000
#define SVf_THINKFIRST  (SVf_READONLY|SVf_PROTECT|SVf_ROK|SVf_FAKE)
#define SVf_OK          (SVf_IOK|SVf_NOK|SVf_POK|SVf_ROK|SVp_IOK|SVp_NOK|SVp_POK)
#define SVf_UTF8        0x20000000

#define SvREFCNT_IMMORTAL ((~(U32)0)/2)

/* ============================================================
 * ANY union — used for CvXSUBANY
 * ============================================================ */

union any {
    void*   any_ptr;
    SV*     any_sv;
    SV**    any_svp;
    GV*     any_gv;
    AV*     any_av;
    HV*     any_hv;
    OP*     any_op;
    char*   any_pv;
    char**  any_pvp;
    I32     any_i32;
    U32     any_u32;
    IV      any_iv;
    UV      any_uv;
    long    any_long;
    bool    any_bool;
};
typedef union any ANY;

/* ============================================================
 * MAGIC struct
 * ============================================================ */

struct mgvtbl {
    int (*svt_get)(SV *sv, MAGIC *mg);
    int (*svt_set)(SV *sv, MAGIC *mg);
    U32 (*svt_len)(SV *sv, MAGIC *mg);
    int (*svt_clear)(SV *sv, MAGIC *mg);
    int (*svt_free)(SV *sv, MAGIC *mg);
    int (*svt_copy)(SV *sv, MAGIC *mg, SV *nsv, const char *name, I32 namlen);
    int (*svt_dup)(MAGIC *mg, void *param);
    int (*svt_local)(SV *nsv, MAGIC *mg);
};

struct magic {
    MAGIC*      mg_moremagic;
    MGVTBL*     mg_virtual;
    U16         mg_private;
    char        mg_type;
    U8          mg_flags;
    SSize_t     mg_len;
    SV*         mg_obj;
    char*       mg_ptr;
};

/* ============================================================
 * xmgu union — used in body structs
 * ============================================================ */

union _xmgu {
    MAGIC*  xmg_magic;
    STRLEN  xmg_hash_index;
};

/* ============================================================
 * SV struct — THE core Perl value type
 *
 * Layout: sv_any (body ptr), sv_refcnt, sv_flags, sv_u (value union)
 * Total: 24 bytes on x86_64
 * ============================================================ */

struct sv {
    void*       sv_any;     /* pointer to body (XPVCV, XPVHV, etc.) */
    U32         sv_refcnt;
    U32         sv_flags;
    union {
        char*   svu_pv;
        IV      svu_iv;
        UV      svu_uv;
        NV      svu_nv;
        SV*     svu_rv;
        SV**    svu_array;
        HE**    svu_hash;
        GP*     svu_gp;
        PerlIO* svu_fp;
    } sv_u;
};

/* AV, HV, CV, GV, IO share the same base layout */
struct av { void* sv_any; U32 sv_refcnt; U32 sv_flags; union { char* svu_pv; IV svu_iv; UV svu_uv; NV svu_nv; SV* svu_rv; SV** svu_array; HE** svu_hash; GP* svu_gp; PerlIO* svu_fp; } sv_u; };
struct hv { void* sv_any; U32 sv_refcnt; U32 sv_flags; union { char* svu_pv; IV svu_iv; UV svu_uv; NV svu_nv; SV* svu_rv; SV** svu_array; HE** svu_hash; GP* svu_gp; PerlIO* svu_fp; } sv_u; };
struct cv { void* sv_any; U32 sv_refcnt; U32 sv_flags; union { char* svu_pv; IV svu_iv; UV svu_uv; NV svu_nv; SV* svu_rv; SV** svu_array; HE** svu_hash; GP* svu_gp; PerlIO* svu_fp; } sv_u; };
struct gv { void* sv_any; U32 sv_refcnt; U32 sv_flags; union { char* svu_pv; IV svu_iv; UV svu_uv; NV svu_nv; SV* svu_rv; SV** svu_array; HE** svu_hash; GP* svu_gp; PerlIO* svu_fp; } sv_u; };
struct io { void* sv_any; U32 sv_refcnt; U32 sv_flags; union { char* svu_pv; IV svu_iv; UV svu_uv; NV svu_nv; SV* svu_rv; SV** svu_array; HE** svu_hash; GP* svu_gp; PerlIO* svu_fp; } sv_u; };
struct op { void* op_next; void* op_sibparent; void* op_ppaddr; U32 op_targ; U16 op_type; U16 op_flags; };
struct cop { struct op cop_op; /* simplified */ };

/* ============================================================
 * XPV body structs
 * ============================================================ */

/* XPV base (used by PV, PVIV, PVNV, PVMG) */
struct xpv {
    HV*         xmg_stash;
    union _xmgu xmg_u;
    STRLEN      xpv_cur;
    union { STRLEN xpvlenu_len; void* xpvlenu_rx; } xpv_len_u;
};
#define xpv_len xpv_len_u.xpvlenu_len

/* XPVHV — hash body */
struct xpvhv {
    HV*         xmg_stash;
    union _xmgu xmg_u;
    STRLEN      xhv_keys;
    STRLEN      xhv_max;
};

/* XPVCV — code value body */
struct xpvcv {
    HV*         xmg_stash;
    union _xmgu xmg_u;
    STRLEN      xpv_cur;
    union { STRLEN xpvlenu_len; void* xpvlenu_rx; } xpv_len_u;
    /* _XPVCV_COMMON fields */
    HV*         xcv_stash;
    union { OP* xcv_start; ANY xcv_xsubany; } xcv_start_u;
    union { OP* xcv_root; void (*xcv_xsub)(CV* cv); } xcv_root_u;
    union { GV* xcv_gv; HEK* xcv_hek; } xcv_gv_u;
    char*       xcv_file;
    union { PADLIST* xcv_padlist; void* xcv_hscxt; } xcv_padlist_u;
    CV*         xcv_outside;
    U32         xcv_outside_seq;
    cv_flags_t  xcv_flags;
    I32         xcv_depth;
};
typedef struct xpvcv XPVCV;

/* ============================================================
 * HE / HEK — hash entry and key
 * ============================================================ */

struct hek {
    U32     hek_hash;
    I32     hek_len;
    char    hek_key[1]; /* variable length */
};

struct he {
    HE*     hent_next;
    HEK*    hent_hek;
    union {
        SV* hent_val;
        Size_t hent_refcount;
    } he_valu;
};

/* ============================================================
 * SV access macros
 * ============================================================ */

#define SvANY(sv)       ((sv)->sv_any)
#define SvFLAGS(sv)     ((sv)->sv_flags)
#define SvREFCNT(sv)    ((sv)->sv_refcnt)
#define SvTYPE(sv)      ((svtype)((sv)->sv_flags & SVt_MASK))

#define SvIVX(sv)       ((sv)->sv_u.svu_iv)
#define SvUVX(sv)       ((sv)->sv_u.svu_uv)
#define SvNVX(sv)       ((sv)->sv_u.svu_nv)
#define SvPVX(sv)       ((sv)->sv_u.svu_pv)
#define SvRV(sv)        ((sv)->sv_u.svu_rv)

#define SvIOK(sv)       (SvFLAGS(sv) & SVf_IOK)
#define SvNOK(sv)       (SvFLAGS(sv) & SVf_NOK)
#define SvPOK(sv)       (SvFLAGS(sv) & SVf_POK)
#define SvROK(sv)       (SvFLAGS(sv) & SVf_ROK)
#define SvOK(sv)        (SvFLAGS(sv) & SVf_OK)
#define SvIOKp(sv)      (SvFLAGS(sv) & SVp_IOK)
#define SvNOKp(sv)      (SvFLAGS(sv) & SVp_NOK)
#define SvPOKp(sv)      (SvFLAGS(sv) & SVp_POK)
#define SvTRUE(sv)      Perl_sv_2bool_flags(aTHX_ sv, 0)
#define SvNIOK(sv)      (SvFLAGS(sv) & (SVf_IOK|SVf_NOK))
#define SvUTF8(sv)      (SvFLAGS(sv) & SVf_UTF8)
#define SvUTF8_on(sv)   (SvFLAGS(sv) |= SVf_UTF8)
#define SvUTF8_off(sv)  (SvFLAGS(sv) &= ~SVf_UTF8)

/* Refcount macros */
#define SvREFCNT_inc(sv)      ((SV*)(sv) ? (++(((SV*)(sv))->sv_refcnt), (SV*)(sv)) : NULL)
#define SvREFCNT_inc_NN(sv)   (++(((SV*)(sv))->sv_refcnt), (SV*)(sv))
#define SvREFCNT_inc_simple(sv) SvREFCNT_inc(sv)
#define SvREFCNT_inc_simple_NN(sv) SvREFCNT_inc_NN(sv)
#define SvREFCNT_dec(sv)      Perl_sv_free(aTHX_ (SV*)(sv))

/* ============================================================
 * HV access macros
 * ============================================================ */

#define HvARRAY(hv)         ((hv)->sv_u.svu_hash)
#define HvMAX(hv)           (((struct xpvhv*)SvANY(hv))->xhv_max)
#define HvTOTALKEYS(hv)     (((struct xpvhv*)SvANY(hv))->xhv_keys)
#define HvUSEDKEYS(hv)      HvTOTALKEYS(hv)
#define HvNAME(hv)          ((hv)->sv_u.svu_pv) /* simplified */

/* HE access macros */
#define HeNEXT(he)          ((he)->hent_next)
#define HeKEY_hek(he)       ((he)->hent_hek)
#define HeVAL(he)           ((he)->he_valu.hent_val)
#define HeKLEN(he)          (HeKEY_hek(he)->hek_len)
#define HeKEY(he)           (HeKEY_hek(he)->hek_key)
#define HeHASH(he)          (HeKEY_hek(he)->hek_hash)
#define HEK_KEY(hek)        ((hek)->hek_key)

/* ============================================================
 * CV access macros
 * ============================================================ */

#define CvXSUB(cv)          (((XPVCV*)SvANY(cv))->xcv_root_u.xcv_xsub)
#define CvXSUBANY(cv)       (((XPVCV*)SvANY(cv))->xcv_start_u.xcv_xsubany)
#define CvGV(cv)            (((XPVCV*)SvANY(cv))->xcv_gv_u.xcv_gv)
#define CvFILE(cv)          (((XPVCV*)SvANY(cv))->xcv_file)
#define CvSTASH(cv)         (((XPVCV*)SvANY(cv))->xcv_stash)
#define CvDEPTH(cv)         (((XPVCV*)SvANY(cv))->xcv_depth)
#define CvFLAGS(cv)         (((XPVCV*)SvANY(cv))->xcv_flags)
#define CvISXSUB(cv)        (CvXSUB(cv) != NULL)
#define CvREFCNT_inc(cv)    ((CV*)SvREFCNT_inc((SV*)(cv)))

/* GV access — simplified: store name in svu_pv */
#define GvNAME(gv)          ((gv)->sv_u.svu_pv ? (gv)->sv_u.svu_pv : "")
#define GvNAMELEN(gv)       ((gv)->sv_u.svu_pv ? (I32)strlen((gv)->sv_u.svu_pv) : 0)
#define GvSTASH(gv)         ((HV*)NULL)
#define GvCV(gv)            ((CV*)(gv)->sv_any) /* we store CV* in gv->sv_any */
#define GvSV(gv)            ((SV*)(gv)->sv_any)
#define isGV(sv)            (SvTYPE(sv) == SVt_PVGV)

/* SvSTASH / SvMAGIC — for blessed objects and magic */
#define SvSTASH(sv)         (((struct xpv*)SvANY(sv))->xmg_stash)
#define SvMAGIC(sv)         (((struct xpv*)SvANY(sv))->xmg_u.xmg_magic)

/* ============================================================
 * XS calling convention macros
 * ============================================================ */

typedef void (*XSUBADDR_t)(CV*);

/* Misc Perl macros */
#define STATIC          static
#define DEFSV           (PL_defgv ? GvSV(PL_defgv) : Perl_newSV(0))
#define ERRSV           (PL_errgv ? GvSV(PL_errgv) : Perl_newSV(0))
#define CLEAR_ERRSV()   do {} while(0)
#define dXSI32          I32 ix __attribute__((unused)) = (I32)XSANY.any_i32
#define cxstack         (PL_curstackinfo ? ((PERL_CONTEXT*)NULL) : NULL)
#define cxstack_ix      (PL_curstackinfo ? 0 : -1)

/* PERL_CONTEXT — opaque for us */
typedef struct { int cx_type; int blk_oldcop; struct { CV* cv; } blk_sub; } PERL_CONTEXT_REAL;
#undef PERL_CONTEXT
#define PERL_CONTEXT PERL_CONTEXT_REAL

/* PERL_SI — stack info (opaque but DBI peeks into it) */
typedef struct perl_si_real {
    AV*   si_stack;
    PERL_CONTEXT_REAL* si_cxstack;
    struct perl_si_real* si_prev;
    struct perl_si_real* si_next;
    I32   si_cxix;
    I32   si_type;
} PERL_SI_REAL;
#undef PERL_SI
#define PERL_SI PERL_SI_REAL

/* Additional constants and macros that DBI uses */
#define TRUE            1
#define FALSE           0
#define Nullch          ((char*)NULL)
#define Nullfp          ((PerlIO*)NULL)
#define IV_MAX          ((IV)((~(UV)0) >> 1))
#define UV_MAX          (~(UV)0)
#define IS_NUMBER_NEG   0x02
#define GV_ADDWARN      0x04
#define G_LIST          G_ARRAY
#define CXt_SUB         1
#define CXt_EVAL        2
#define PERLSI_MAIN     0
#define MGf_DUP         0x08
#define PERL_MAGIC_tied 'P'
#define PERL_GET_THX    ((void*)0)
#define PL_Sv           Perl_newSV(0)
#define TAINT           do {} while(0)
#define TAINT_NOT       do {} while(0)
#define SAVE_DEFSV      do {} while(0)
#define dTHR
#define aTHXo_

/* Stack macros DBI uses */
#define POPi            ((I32)SvIV(POPs))
#define POPl            ((long)SvIV(POPs))
#define POPn            SvNV(POPs)
#define POPp            SvPV_nolen(POPs)
#define XSprePUSH       (sp = PL_stack_base + ax - 1)
#define MSPAGAIN        SPAGAIN
#define PUSHi(i)        PUSHs(Perl_newSViv(i))
#define PUSHn(n)        PUSHs(Perl_newSVnv(n))
#define PUSHp(s,l)      PUSHs(Perl_newSVpvn(s,l))
#define XPUSHi(i)       XPUSHs(Perl_newSViv(i))
#define XPUSHn(n)       XPUSHs(Perl_newSVnv(n))
#define XPUSHp(s,l)     XPUSHs(Perl_newSVpvn(s,l))
#define TARG            PL_Sv
#define dXSTARG         SV *targ __attribute__((unused)) = TARG
#define TARGi(i,m)      Perl_newSViv(i)
#define TARGn(n,m)      Perl_newSVnv(n)

/* errno */
#include <errno.h>

/* Interpreter — not used (single-threaded) */
typedef struct { int dummy; } PerlInterpreter;
#define pTHX      void
#define pTHX_
#define aTHX
#define aTHX_
#define dTHX
#define PERL_SET_THX(t)
#define PERL_NO_GET_CONTEXT

/* Stack */
extern SV **PL_stack_base;
extern SV **PL_stack_sp;
extern SV **PL_stack_max;
extern Stack_off_t *PL_markstack;
extern Stack_off_t *PL_markstack_ptr;
extern Stack_off_t *PL_markstack_max;

#define SP          PL_stack_sp
#define dSP         SV **sp __attribute__((unused)) = PL_stack_sp
#define SPAGAIN     sp = PL_stack_sp
#define PUTBACK     PL_stack_sp = sp
#define PUSHMARK(p) (*++PL_markstack_ptr = (Stack_off_t)(sp - PL_stack_base))
#define TOPMARK     (*PL_markstack_ptr)
#define POPMARK     (*PL_markstack_ptr--)
#define dMARK       SV **mark = PL_stack_base + POPMARK
#define dORIGMARK   const Stack_off_t origmark = (Stack_off_t)(mark - PL_stack_base)

#define PUSHs(sv)   (*++sp = (sv))
#define XPUSHs(sv)  (*++sp = (sv))
#define POPs        (*sp--)
#define TOPs        (*sp)
#define SETs(sv)    (*sp = (sv))

#define ENTER       do {} while(0)
#define LEAVE       do {} while(0)
#define SAVETMPS    do {} while(0)
#define FREETMPS    do {} while(0)

/* XS argument handling */
#define dXSARGS \
    dSP; \
    Stack_off_t ax = (Stack_off_t)(PL_markstack_ptr > PL_markstack ? TOPMARK + 1 : 0); \
    SSize_t items = (SSize_t)(sp - PL_stack_base) - ax + 1; \
    (void)items

#define dXSBOOTARGSXSAPIVERCHK dXSARGS
#define dVAR

#define ST(n)           (PL_stack_base[ax + (n)])
#define XSRETURN(n)     do { PL_stack_sp = sp; return; } while(0)
#define XSRETURN_YES    do { XPUSHs(&PL_sv_yes); XSRETURN(1); } while(0)
#define XSRETURN_NO     do { XPUSHs(&PL_sv_no); XSRETURN(1); } while(0)
#define XSRETURN_UNDEF  do { XPUSHs(&PL_sv_undef); XSRETURN(1); } while(0)
#define XSRETURN_IV(iv) do { XPUSHs(Perl_newSViv(iv)); XSRETURN(1); } while(0)
#define XSRETURN_EMPTY  XSRETURN(0)

#define GIMME_V         0  /* scalar context */
#define G_SCALAR        0
#define G_ARRAY         1
#define G_VOID          2
#define G_DISCARD       4
#define G_EVAL          8
#define G_NOARGS        16
#define G_KEEPERR       32
#define G_WANT          3

/* XS function registration */
#define XS(name)          void name(CV* cv)
#define XS_INTERNAL(name) static XS(name)
#define XS_EXTERNAL(name) XS(name)
#define XS_VERSION        NULL
#define XS_APIVERSION_BOOTCHECK do {} while(0)
#define XS_VERSION_BOOTCHECK    do {} while(0)
#define XSANY             CvXSUBANY(cv)

#define newXSproto(a,b,c,d)     Perl_newXS(a,b,c)
#define newXSproto_portable     newXSproto

/* ============================================================
 * Immortal SVs
 * ============================================================ */

extern SV PL_sv_immortals[];
#define PL_sv_undef     PL_sv_immortals[0]
#define PL_sv_yes       PL_sv_immortals[1]
#define PL_sv_no        PL_sv_immortals[2]

/* ============================================================
 * Other PL_ globals
 * ============================================================ */

extern SV       *PL_sv_root;
extern IV        PL_sv_count;
extern OP       *PL_op;
extern COP      *PL_curcop;
extern SV      **PL_curpad;
extern PERL_SI  *PL_curstackinfo;
extern GV       *PL_defgv;
extern GV       *PL_errgv;
extern GV       *PL_DBsub;
extern bool      PL_tainted;
extern bool      PL_tainting;
extern bool      PL_dowarn;
extern int       PL_phase;
extern int       PL_perl_destruct_level;
extern U32       PL_sub_generation;
extern bool      PL_in_utf8_CTYPE_locale;
extern void     *PL_body_roots[];
extern SSize_t   PL_tmps_ix;
extern SSize_t   PL_tmps_floor;
extern const U8  PL_latin1_lc[];
extern const U8  PL_mod_latin1_uc[];
extern U32       PL_charclass[];
extern const char PL_memory_wrap[];

/* ============================================================
 * SV creation / access functions (implemented in perla_perl_api.c)
 * ============================================================ */

#define PERL_CALLCONV
#define PERL_ARGS_ASSERT_CROAK

extern SV*    Perl_newSV(STRLEN len);
extern SV*    Perl_newSViv(IV i);
extern SV*    Perl_newSVuv(UV u);
extern SV*    Perl_newSVnv(NV n);
extern SV*    Perl_newSVpv(const char *s, STRLEN len);
extern SV*    Perl_newSVpvn(const char *s, STRLEN len);
extern SV*    Perl_newSVpvf(const char *fmt, ...);
extern SV*    Perl_newSVsv_flags(SV * const old, I32 flags);
extern SV*    Perl_newRV(SV *referent);
extern CV*    Perl_newXS(const char *name, XSUBADDR_t func, const char *file);
extern CV*    Perl_newXS_flags(const char *name, XSUBADDR_t func, const char *file, const char *proto, U32 flags);

extern IV     Perl_sv_2iv_flags(SV *sv, I32 flags);
extern UV     Perl_sv_2uv_flags(SV *sv, I32 flags);
extern NV     Perl_sv_2nv_flags(SV *sv, I32 flags);
extern char*  Perl_sv_2pv_flags(SV *sv, STRLEN *lp, U32 flags);
extern char*  Perl_sv_2pvbyte_flags(SV *sv, STRLEN *lp, U32 flags);
extern bool   Perl_sv_2bool_flags(SV *sv, I32 flags);
extern SV*    Perl_sv_2mortal(SV *sv);
extern SV*    Perl_sv_newmortal(void);

extern void   Perl_sv_setiv(SV *sv, IV i);
extern void   Perl_sv_setnv(SV *sv, NV n);
extern void   Perl_sv_setpv(SV *sv, const char *s);
extern void   Perl_sv_setpvn(SV *sv, const char *s, STRLEN len);
extern void   Perl_sv_setpvf(SV *sv, const char *fmt, ...);
extern void   Perl_sv_setsv_flags(SV *dsv, SV *ssv, I32 flags);
extern void   Perl_sv_catpv(SV *sv, const char *s);
extern void   Perl_sv_catpvn_flags(SV *sv, const char *s, STRLEN len, I32 flags);
extern void   Perl_sv_catpvf(SV *sv, const char *fmt, ...);
extern void   Perl_sv_catsv_flags(SV *dsv, SV *ssv, I32 flags);
extern void   Perl_sv_free(SV *sv);
extern void   Perl_sv_upgrade(SV *sv, svtype new_type);
extern SV*    Perl_sv_bless(SV *sv, HV *stash);
extern int    Perl_sv_isobject(SV *sv);
extern bool   Perl_sv_derived_from(SV *sv, const char * const name);
extern const char* Perl_sv_reftype(const SV *sv, int ob);
extern void   Perl_sv_magic(SV *sv, SV *obj, int how, const char *name, I32 namlen);
extern MAGIC* Perl_sv_magicext(SV *sv, SV *obj, int how, const MGVTBL *vtbl, const char *name, I32 namlen);
extern int    Perl_sv_unmagic(SV *sv, int type);
extern MAGIC* Perl_mg_find(const SV *sv, int type);

extern void   Perl_av_push(AV *av, SV *val);
extern SV**   Perl_av_fetch(AV *av, SSize_t key, I32 lval);
extern SV**   Perl_av_store(AV *av, SSize_t key, SV *val);
extern SSize_t Perl_av_len(AV *av);
extern void   Perl_av_extend(AV *av, SSize_t key);

extern void*  Perl_hv_common_key_len(HV *hv, const char *key, I32 klen, const int action, SV *val, const U32 hash);
extern void*  Perl_hv_common(HV *hv, SV *keysv, const char *key, STRLEN klen, int flags, int action, SV *val, U32 hash);
extern I32    Perl_hv_iterinit(HV *hv);
extern HE*    Perl_hv_iternext_flags(HV *hv, I32 flags);
extern SV*    Perl_hv_iternextsv(HV *hv, char **key, I32 *klen);

extern HV*    Perl_gv_stashpv(const char *name, I32 flags);
extern SV*    Perl_get_sv(const char *name, I32 flags);
extern CV*    Perl_get_cv(const char *name, I32 flags);

extern SSize_t Perl_call_sv(SV *sv, I32 flags);
extern SSize_t Perl_call_method(const char *method, I32 flags);

extern void   Perl_croak(const char *fmt, ...);
extern void   Perl_warn(const char *fmt, ...);
extern OP*    Perl_die(const char *fmt, ...);

extern Stack_off_t Perl_xs_handshake(const U32 key, void *v_my_perl, const char *file, ...);
extern void   Perl_xs_boot_epilog(const SSize_t ax);

/* ============================================================
 * Convenience macros used by XS code
 * ============================================================ */

#define newSV(n)            Perl_newSV(n)
#define newSViv(i)          Perl_newSViv(i)
#define newSVuv(u)          Perl_newSVuv(u)
#define newSVnv(n)          Perl_newSVnv(n)
#define newSVpv(s,l)        Perl_newSVpv(s,l)
#define newSVpvn(s,l)       Perl_newSVpvn(s,l)
#define newSVpvf            Perl_newSVpvf
#define newSVsv(sv)         Perl_newSVsv_flags(sv, 0)
#define newRV_noinc(sv)     Perl_newRV(sv)
#define newRV_inc(sv)       ({ SvREFCNT_inc(sv); Perl_newRV(sv); })
#define newHV()             ((HV*)Perl_newSV_type(SVt_PVHV))
#define newAV()             ((AV*)Perl_newSV_type(SVt_PVAV))
extern SV* Perl_newSV_type(const svtype type);

#define sv_2mortal(sv)      Perl_sv_2mortal(sv)
#define sv_setsv(d,s)       Perl_sv_setsv_flags(d,s,0)

#define SvIV(sv)            Perl_sv_2iv_flags(sv, 0)
#define SvUV(sv)            Perl_sv_2uv_flags(sv, 0)
#define SvNV(sv)            Perl_sv_2nv_flags(sv, 0)
#define SvPV(sv, len)       Perl_sv_2pv_flags(sv, &(len), 0)
#define SvPV_nolen(sv)      Perl_sv_2pv_flags(sv, NULL, 0)
#define SvPVbyte(sv, len)   Perl_sv_2pvbyte_flags(sv, &(len), 0)
#define SvCUR(sv)           (SvPOK(sv) ? strlen(SvPVX(sv)) : 0)

#define hv_store(hv,k,l,v,h)   Perl_hv_common_key_len(hv,k,l,0x02,v,h)
#define hv_fetch(hv,k,l,lv)    ((SV**)Perl_hv_common_key_len(hv,k,l,0,NULL,0))
#define hv_exists(hv,k,l)      (Perl_hv_common_key_len(hv,k,l,0,NULL,0) != NULL)
#define hv_delete(hv,k,l,f)    Perl_hv_common_key_len(hv,k,l,0x04,NULL,0)
#define hv_iterinit(hv)         Perl_hv_iterinit(hv)
#define hv_iternextsv(hv,k,l)   Perl_hv_iternextsv(hv,k,l)

#define call_sv(sv,f)       Perl_call_sv(sv,f)
#define call_method(m,f)    Perl_call_method(m,f)
#define get_sv(n,f)         Perl_get_sv(n,f)
#define get_cv(n,f)         Perl_get_cv(n,f)

#define sv_setiv(sv,i)      Perl_sv_setiv(sv,i)
#define sv_setiv_mg(sv,i)   Perl_sv_setiv(sv,i)
#define sv_setnv(sv,n)      Perl_sv_setnv(sv,n)
#define sv_setnv_mg(sv,n)   Perl_sv_setnv(sv,n)
#define sv_setpv(sv,s)      Perl_sv_setpv(sv,s)
#define sv_setpvn(sv,s,l)   Perl_sv_setpvn(sv,s,l)
#define sv_catpv(sv,s)      Perl_sv_catpv(sv,s)
#define sv_catpvn(sv,s,l)   Perl_sv_catpvn_flags(sv,s,l,0)
#define sv_bless(sv,st)     Perl_sv_bless(sv,st)

#define croak               Perl_croak
#define warn                Perl_warn

/* Memory */
#define Newx(p,n,t)         (p = (t*)malloc((n)*sizeof(t)))
#define Newxz(p,n,t)        (p = (t*)calloc(n, sizeof(t)))
#define Renew(p,n,t)        (p = (t*)realloc(p, (n)*sizeof(t)))
#define Safefree(p)         free(p)
#define Copy(s,d,n,t)       memcpy(d,s,(n)*sizeof(t))
#define Move(s,d,n,t)       memmove(d,s,(n)*sizeof(t))
#define Zero(d,n,t)         memset(d,0,(n)*sizeof(t))
#define savepv(s)           strdup(s)
#define savepvn(s,n)        strndup(s,n)

/* String comparison */
#define strEQ(a,b)          (strcmp(a,b) == 0)
#define strNE(a,b)          (strcmp(a,b) != 0)
#define strnEQ(a,b,n)       (strncmp(a,b,n) == 0)
#define strnNE(a,b,n)       (strncmp(a,b,n) != 0)

/* MY_CXT — per-module context (non-threaded) */
#define START_MY_CXT        static my_cxt_t my_cxt;
#define dMY_CXT
#define MY_CXT_INIT
#define MY_CXT_CLONE
#define MY_CXT              my_cxt
#define dMY_CXT_INTERP(p)
#define aMY_CXT
#define aMY_CXT_
#define _aMY_CXT
#define pMY_CXT             void
#define pMY_CXT_

/* Misc */
#define PERL_UNUSED_VAR(x)  ((void)(x))
#define PERL_UNUSED_ARG(x)  ((void)(x))
#define NOOP                do {} while(0)
#define dNOOP               extern int perla_dummy_noop __attribute__((unused))
#define MUTABLE_SV(p)       ((SV*)(p))
#define MUTABLE_AV(p)       ((AV*)(p))
#define MUTABLE_HV(p)       ((HV*)(p))
#define MUTABLE_CV(p)       ((CV*)(p))
#define MUTABLE_IO(p)       ((IO*)(p))
#define MUTABLE_GV(p)       ((GV*)(p))
#define MUTABLE_PTR(p)      ((void*)(p))

#define PERL_VERSION        42
#define PERL_SUBVERSION     0
#define PERL_REVISION       5
#define PERL_DECIMAL_VERSION 5042000
#define PERL_VERSION_LE(r,v,s) (PERL_DECIMAL_VERSION <= (r*1000000 + v*1000 + s))
#define PERL_VERSION_GE(r,v,s) (PERL_DECIMAL_VERSION >= (r*1000000 + v*1000 + s))
#define PERL_VERSION_LT(r,v,s) (PERL_DECIMAL_VERSION < (r*1000000 + v*1000 + s))

/* GV_ADDMULTI flag for get_sv */
#define GV_ADDMULTI   0x02

/* Perl phases */
#define PERL_PHASE_CONSTRUCT 0
#define PERL_PHASE_START     1
#define PERL_PHASE_RUN       4
#define PERL_PHASE_DESTRUCT  6

/* These are aliases that EXTERN.h / perl.h normally provide */
#define EXT     extern
#define INIT(x)
#define EXTCONST extern const

/* ANSI prototype macro */
#define _(args) args
#define __attribute__format__(a,b,c)
#define PERL_UNUSED_DECL __attribute__((unused))

/* Perl compatibility stubs */
#define Perl_safesysmalloc(n)   malloc(n)
#define Perl_safesyscalloc(n,s) calloc(n,s)
#define Perl_safesysrealloc(p,n) realloc(p,n)
#define Perl_safesysfree(p)     free(p)

/* PerlIO mapped to stdio */
#define PerlIO_printf           fprintf
#define PerlIO_puts(f,s)        fputs(s,f)
#define PerlIO_open(f,m)        fopen(f,m)
extern PerlIO* Perl_PerlIO_stderr(void);
extern PerlIO* Perl_PerlIO_stdout(void);
extern int Perl_PerlIO_close(PerlIO *f);
extern int Perl_PerlIO_flush(PerlIO *f);
extern void Perl_PerlIO_setlinebuf(PerlIO *f);

/* Additional stubs DBI needs */
extern int    Perl_mg_get(SV *sv);
extern SSize_t Perl_mg_size(SV *sv);
extern void   Perl_sv_dump(SV *sv);
extern char*  Perl_sv_grow(SV *sv, STRLEN len);
extern void   Perl_sv_inc(SV *sv);
extern void   Perl_sv_force_normal_flags(SV *sv, U32 flags);
extern bool   Perl_sv_utf8_decode(SV *sv);
extern bool   Perl_sv_tainted(SV *sv);
extern SV*    Perl_sv_rvweaken(SV *sv);
extern void   Perl_sv_backoff(SV *sv);
extern void   Perl_sv_setuv(SV *sv, UV u);
extern SV*    Perl_sv_mortalcopy_flags(SV *sv, U32 flags);
extern int    Perl_looks_like_number(SV *sv);
extern int    Perl_grok_number(const char *s, STRLEN len, UV *result);
extern SV*    Perl_av_pop(AV *av);
extern SV*    Perl_av_shift(AV *av);
extern AV*    Perl_av_make(SSize_t size, SV **svp);
extern void   Perl_av_fill(AV *av, SSize_t fill);
extern void   Perl_hv_clear(HV *hv);
extern I32    Perl_hv_placeholders_get(const HV *hv);
extern char*  Perl_hv_iterkey(HE *he, I32 *klen);
extern SV*    Perl_hv_iterval(HV *hv, HE *he);
extern HV*    Perl_gv_stashsv(SV *sv, I32 flags);
extern GV*    Perl_gv_fetchpv(const char *name, I32 flags, const svtype sv_type);
extern GV*    Perl_gv_fetchmethod_autoload(HV *stash, const char *name, I32 autoload);
extern void   Perl_gv_efullname4(SV *sv, const GV *gv, const char *prefix, bool keepmain);
extern GV*    Perl_gv_add_by_type(GV *gv, svtype type);
extern GV*    Perl_cvgv_from_hek(CV *cv);
extern void*  Perl_mro_meta_init(HV *stash);
extern void   Perl_croak_sv(SV *sv);
extern void   Perl_warn_sv(SV *sv);
extern void   Perl_croak_xs_usage(const CV * const cv, const char * const params);
extern void   Perl_taint_proper(const char *f, const char *s);
extern IO*    Perl_sv_2io(SV *sv);
extern void   Perl_sv_insert_flags(SV *sv, STRLEN offset, STRLEN len, const char *s, STRLEN slen, U32 flags);
extern void   Perl_require_pv(const char *name);
extern Stack_off_t* Perl_markstack_grow(void);
extern SV**   Perl_stack_grow(SV **sp, SV **p, SSize_t n);
extern void*  Perl_more_bodies(svtype sv_type, size_t body_size, size_t arena_size);
extern SV*    Perl_more_sv(void);
extern void   Perl_save_I32(I32 *p);
extern void   Perl_save_int(int *p);
extern void   Perl_save_sptr(SV **p);
extern void   Perl_savetmps(void);
extern void   Perl_free_tmps(void);
extern void   Perl_push_scope(void);
extern void   Perl_pop_scope(void);
extern int    Perl_runops_standard(void);
extern CV*    Perl_newXS_deffile(const char *name, XSUBADDR_t func);
extern void   Perl_sv_free2(SV *sv, U32 rc);

#define sv_mortalcopy(sv) Perl_sv_mortalcopy_flags(sv, 0)
#define newXS(n,f,file)   Perl_newXS(n,f,file)

/* PERL_POLLUTE compat */
#define PERL_POLLUTE

/* Missing constants and macros */
#define Nullsv          ((SV*)NULL)
#define Nullav          ((AV*)NULL)
#define Nullhv          ((HV*)NULL)
#define Nullcv          ((CV*)NULL)
#define Nullgv          ((GV*)NULL)
#define PL_dirty        0
#define PL_in_clean_all 0
#define IS_NUMBER_IN_UV 0x01

/* printf format macros for Perl types */
#define IVdf            "ld"
#define UVuf            "lu"
#define UVxf            "lx"
#define NVef            "e"
#define NVff            "f"
#define NVgf            "g"
#define SVf             "s"
#define SVf_QUOTEDPREFIX "s"
#define HEKf            "s"
#define UTF8f           "s"
#define SVfARG(sv)      (SvPOK(sv) ? SvPVX(sv) : "")

/* Casting macros */
#define INT2PTR(t,v)    ((t)(uintptr_t)(v))
#define PTR2IV(p)       ((IV)(uintptr_t)(p))
#define PTR2UV(p)       ((UV)(uintptr_t)(p))
#define NUM2PTR(t,v)    ((t)(uintptr_t)(v))
#define PTR2nat(p)      ((uintptr_t)(p))

/* SV type checking */
#define SvNIOK(sv)      (SvFLAGS(sv) & (SVf_IOK|SVf_NOK))
#define SvNIOKp(sv)     (SvFLAGS(sv) & (SVp_IOK|SVp_NOK))
#define SvMAGICAL(sv)   (SvFLAGS(sv) & (SVs_GMG|SVs_SMG|SVs_RMG))
#define SvGMAGICAL(sv)  (SvFLAGS(sv) & SVs_GMG)
#define SvOBJECT(sv)    (SvFLAGS(sv) & SVs_OBJECT)
#define SvTEMP(sv)      (SvFLAGS(sv) & SVs_TEMP)

#define SvIV_set(sv,i)  ((sv)->sv_u.svu_iv = (i))
#define SvNV_set(sv,n)  ((sv)->sv_u.svu_nv = (n))
#define SvPV_set(sv,p)  ((sv)->sv_u.svu_pv = (p))
#define SvRV_set(sv,r)  ((sv)->sv_u.svu_rv = (r))

#define SvIOK_on(sv)    (SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))
#define SvNOK_on(sv)    (SvFLAGS(sv) |= (SVf_NOK|SVp_NOK))
#define SvPOK_on(sv)    (SvFLAGS(sv) |= (SVf_POK|SVp_POK))
#define SvROK_on(sv)    (SvFLAGS(sv) |= SVf_ROK)
#define SvIOK_off(sv)   (SvFLAGS(sv) &= ~(SVf_IOK|SVp_IOK))
#define SvNOK_off(sv)   (SvFLAGS(sv) &= ~(SVf_NOK|SVp_NOK))
#define SvPOK_off(sv)   (SvFLAGS(sv) &= ~(SVf_POK|SVp_POK))
#define SvROK_off(sv)   (SvFLAGS(sv) &= ~SVf_ROK)

#define SvPOK_only(sv)  (SvFLAGS(sv) = (SvFLAGS(sv) & ~(SVf_OK|SVf_ROK)) | SVf_POK | SVp_POK)

#define SvLEN(sv)       (SvPOK(sv) && SvANY(sv) ? ((struct xpv*)SvANY(sv))->xpv_len : 0)
#define SvLEN_set(sv,l) do { if (SvANY(sv)) ((struct xpv*)SvANY(sv))->xpv_len = (l); } while(0)
#define SvCUR_set(sv,l) do { if (SvANY(sv)) ((struct xpv*)SvANY(sv))->xpv_cur = (l); } while(0)
#define SvEND(sv)       (SvPVX(sv) + SvCUR(sv))

/* Stash access for blessed objects */
#define SvSTASH_set(sv,st) do { if (SvANY(sv)) ((struct xpv*)SvANY(sv))->xmg_stash = (st); } while(0)

/* HV_FETCH flags */
#define HV_FETCH_ISSTORE    0x02
#define HV_DELETE            0x04

/* DBI helper — looks_like_number */
#define looks_like_number(sv) Perl_looks_like_number(sv)

/* Stub headers that XS modules #include */
/* EXTERN.h and XSUB.h are provided by including this file */

#endif /* PERLA_PERL_H */
