/*
 * perl_compat.h — Map Perl's C API types/macros to Strada's runtime
 *
 * This allows XS modules to compile against the Strada runtime instead
 * of Perl's internals. Covers the most commonly used XS patterns.
 */

#ifndef PERL_COMPAT_H
#define PERL_COMPAT_H

#include "strada_runtime.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

/* ===== Perl type aliases ===== */

typedef StradaValue* SV;
typedef StradaValue* AV;
typedef StradaValue* HV;
typedef StradaValue* CV;
typedef int64_t IV;
typedef uint64_t UV;
typedef double NV;
typedef char* PV;
typedef size_t STRLEN;
typedef int I32;
typedef unsigned int U32;
typedef int bool_t;

/* ===== SV accessors ===== */

#define SvIV(sv)    strada_to_int(sv)
#define SvIVX(sv)   strada_to_int(sv)
#define SvNV(sv)    strada_to_num(sv)
#define SvNVX(sv)   strada_to_num(sv)
#define SvPV_nolen(sv) ({                           \
    char *__pv = strada_to_str(sv);                 \
    __pv;  /* caller must free! */                  \
})
#define SvPV(sv, len) ({                            \
    char *__pv = strada_to_str(sv);                 \
    (len) = __pv ? strlen(__pv) : 0;                \
    __pv;                                           \
})
#define SvUV(sv)    ((UV)strada_to_int(sv))
#define SvTRUE(sv)  strada_to_bool(sv)
#define SvOK(sv)    (sv && !STRADA_IS_TAGGED_INT(sv) && sv->type != STRADA_UNDEF)
#define SvIOK(sv)   (STRADA_IS_TAGGED_INT(sv) || (!STRADA_IS_TAGGED_INT(sv) && sv && sv->type == STRADA_INT))
#define SvNOK(sv)   (!STRADA_IS_TAGGED_INT(sv) && sv && sv->type == STRADA_NUM)
#define SvPOK(sv)   (!STRADA_IS_TAGGED_INT(sv) && sv && sv->type == STRADA_STR)
#define SvROK(sv)   (!STRADA_IS_TAGGED_INT(sv) && sv && sv->type == STRADA_REF)
#define SvRV(sv)    (sv->value.rv)
#define SvREFCNT_inc(sv) ({ if (sv && !STRADA_IS_TAGGED_INT(sv)) strada_incref(sv); sv; })
#define SvREFCNT_dec(sv) ({ if (sv && !STRADA_IS_TAGGED_INT(sv)) strada_decref(sv); })
#define SvREFCNT(sv)     (STRADA_IS_TAGGED_INT(sv) ? 999 : sv->refcount)

/* ===== SV constructors ===== */

#define newSViv(val)     STRADA_MAKE_TAGGED_INT(val)
#define newSVuv(val)     STRADA_MAKE_TAGGED_INT((int64_t)(val))
#define newSVnv(val)     strada_new_num(val)
#define newSVpv(str,len) strada_new_str(str)
#define newSVpvn(str,len) ({                        \
    StradaValue *__sv = strada_new_undef();         \
    __sv->type = STRADA_STR;                        \
    __sv->value.pv = strndup(str, len);             \
    __sv;                                           \
})
#define newSVpvs(str)    strada_new_str(str)
#define newSVsv(sv)      ({                         \
    StradaValue *__c;                               \
    if (STRADA_IS_TAGGED_INT(sv)) __c = sv;         \
    else if (sv->type == STRADA_INT) __c = strada_new_int(sv->value.iv); \
    else if (sv->type == STRADA_NUM) __c = strada_new_num(sv->value.nv); \
    else if (sv->type == STRADA_STR) __c = strada_new_str(sv->value.pv); \
    else { __c = sv; strada_incref(__c); }          \
    __c;                                            \
})
#define newSV(len)       strada_new_undef()
#define sv_newmortal()   strada_new_undef()
#define sv_2mortal(sv)   (sv)  /* Strada uses refcounting, no mortal stack */
#define SvREFCNT_inc_simple_void_NN(sv) strada_incref(sv)

/* ===== SV setters ===== */

#define sv_setiv(sv, val) do {                      \
    strada_decref(sv);                              \
    sv = STRADA_MAKE_TAGGED_INT(val);               \
} while(0)
#define sv_setnv(sv, val) do {                      \
    strada_decref(sv);                              \
    sv = strada_new_num(val);                       \
} while(0)
#define sv_setpv(sv, str) do {                      \
    strada_decref(sv);                              \
    sv = strada_new_str(str);                       \
} while(0)
#define sv_setpvn(sv, str, len) do {                \
    strada_decref(sv);                              \
    sv = strada_new_str(str);                       \
} while(0)
#define sv_setsv(dst, src) do {                     \
    StradaValue *__old = dst;                       \
    dst = newSVsv(src);                             \
    strada_decref(__old);                           \
} while(0)

/* ===== Array operations ===== */

#define av_len(av)      ((int)strada_array_length(strada_deref_array(av)) - 1)
#define AvFILL(av)      av_len(av)
#define av_fetch(av, idx, lval) ({                  \
    StradaArray *__av = strada_deref_array(av);     \
    int __i = (idx);                                \
    (__i >= 0 && (size_t)__i < strada_array_length(__av)) ? &__av->elements[__av->head + __i] : NULL; \
})
#define av_store(av, idx, val)   strada_array_set(strada_deref_array(av), idx, val)
#define av_push(av, val)         strada_array_push(strada_deref_array(av), val)
#define av_pop(av)               strada_array_pop(strada_deref_array(av))
#define av_shift(av)             strada_array_shift(strada_deref_array(av))
#define av_unshift(av, n)        /* not directly supported */
#define av_clear(av)             /* TODO */
#define newAV()                  strada_new_array()

/* ===== Hash operations ===== */

#define hv_fetch(hv, key, klen, lval)  ({           \
    StradaValue *__r = strada_hv_fetch_owned(hv, key); \
    &__r;                                           \
})
#define hv_store(hv, key, klen, val, hash) strada_hv_store(hv, key, val)
#define hv_exists(hv, key, klen)  strada_hash_exists(strada_deref_hash(hv), key)
#define hv_delete(hv, key, klen, flags) strada_hash_delete(strada_deref_hash(hv), key)
#define newHV()                   strada_new_hash()

/* ===== Blessed references ===== */

#define sv_bless(rv, stash)       strada_bless(rv, stash)
#define SvSTASH(sv)               SV_BLESSED(sv)
#define HvNAME(hv)                SV_BLESSED(hv)

/* ===== String utilities ===== */

#define savepv(str)     strdup(str)
#define savepvn(str,n)  strndup(str,n)
#define Safefree(ptr)   free(ptr)
#define Newx(ptr, n, type) ptr = (type*)malloc((n) * sizeof(type))
#define Newxz(ptr, n, type) ptr = (type*)calloc(n, sizeof(type))
#define Renew(ptr, n, type) ptr = (type*)realloc(ptr, (n) * sizeof(type))
#define Copy(src, dst, n, type) memcpy(dst, src, (n) * sizeof(type))
#define Zero(dst, n, type)  memset(dst, 0, (n) * sizeof(type))
#define Move(src, dst, n, type) memmove(dst, src, (n) * sizeof(type))

/* ===== Misc Perl macros ===== */

#define dSP             /* no-op — Strada doesn't use a stack machine */
#define ENTER           /* no-op */
#define SAVETMPS        /* no-op */
#define PUSHMARK(sp)    /* no-op */
#define PUTBACK         /* no-op */
#define SPAGAIN         /* no-op */
#define FREETMPS        /* no-op */
#define LEAVE           /* no-op */
#define EXTEND(sp, n)   /* no-op */
#define PUSHs(sv)       /* no-op — handle differently per function */
#define XPUSHs(sv)      /* no-op */
#define POPs            strada_new_undef()  /* placeholder */
#define POPi            0                   /* placeholder */
#define POPn            0.0                 /* placeholder */
#define POPp            ""                  /* placeholder */

#define XSRETURN(n)     return
#define XSRETURN_IV(iv) return STRADA_MAKE_TAGGED_INT(iv)
#define XSRETURN_NV(nv) return strada_new_num(nv)
#define XSRETURN_PV(pv) return strada_new_str(pv)
#define XSRETURN_YES    return STRADA_MAKE_TAGGED_INT(1)
#define XSRETURN_NO     return STRADA_MAKE_TAGGED_INT(0)
#define XSRETURN_UNDEF  return strada_new_undef()
#define XSRETURN_EMPTY  return strada_new_undef()

/* ===== Warnings / errors ===== */

#define croak(...)      do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); exit(1); } while(0)
#define warn(...)       do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#define Perl_croak_nocontext(...)  croak(__VA_ARGS__)
#define Perl_warn_nocontext(...)   warn(__VA_ARGS__)

/* ===== XS macros ===== */

#define XS(name)        StradaValue* name(StradaValue *self, StradaValue *args)
#define dXSARGS         StradaArray *__items_av = args ? strada_deref_array(args) : NULL; \
                        int items = __items_av ? (int)strada_array_length(__items_av) : 0
#define ST(n)           (__items_av ? strada_array_get(__items_av, n) : strada_new_undef())
#define RETVAL          __retval
#define dXSTARG         /* no-op */
#define XSprePUSH       /* no-op */
#define PUSHi(i)        return STRADA_MAKE_TAGGED_INT(i)
#define PUSHn(n)        return strada_new_num(n)
#define PUSHp(p,l)      return strada_new_str(p)
#define TARG            strada_new_undef()

/* ===== Perl interpreter ===== */

#define aTHX_           /* no-op — no interpreter context */
#define pTHX_           /* no-op */
#define aTHX            /* no-op */
#define pTHX            /* no-op */
#define dTHX            /* no-op */
#define PERL_UNUSED_VAR(x) (void)(x)

/* ===== Errno ===== */

#define ERRSV            strada_new_str(strerror(errno))
#define CLEAR_ERRSV()    /* no-op */

#endif /* PERL_COMPAT_H */
