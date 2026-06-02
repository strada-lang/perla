/*
 * perla_xs_bridge.c — StradaValue ↔ Perl SV bridge for DBI
 *
 * Converts between Perla's StradaValue types and Perl's SV types
 * at the boundary where Perla-generated code calls DBI/DBD XS modules.
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Include Strada runtime for StradaValue types */
/* We can't include strada_runtime.h directly because it conflicts with perl.h types.
 * Instead, forward-declare what we need and use opaque pointers. */
typedef struct StradaValue StradaValue;
typedef struct StradaArray StradaArray;
typedef struct StradaHash  StradaHash;

/* Strada functions we call — declared here to avoid header conflicts */
extern StradaValue* strada_new_str(const char *s);
extern StradaValue* strada_new_str_len(const char *s, size_t len);
extern StradaValue* strada_new_int(int64_t v);
extern StradaValue* strada_new_num(double v);
extern StradaValue* strada_new_undef(void);
extern StradaValue* strada_new_hash(void);
extern StradaValue* strada_new_array(void);
extern StradaValue* strada_new_ref(StradaValue *rv, char sigil);
extern StradaValue* strada_cpointer_new(void *ptr);
extern char* strada_to_str(StradaValue *sv);
extern int64_t strada_to_int(StradaValue *sv);
extern double strada_to_num(StradaValue *sv);
extern StradaHash* strada_deref_hash(StradaValue *sv);
extern StradaArray* strada_deref_array(StradaValue *sv);
extern void strada_hash_set(StradaHash *hv, const char *key, StradaValue *val);
extern void strada_array_push(StradaArray *av, StradaValue *val);
extern void strada_incref(StradaValue *sv);

/* Check if StradaValue is a tagged int */
#define STRADA_SV_IS_TAGGED_INT(sv) ((uintptr_t)(sv) & 1)
#define STRADA_SV_TAGGED_INT_VAL(sv) ((int64_t)(uintptr_t)(sv) >> 1)

/* Perl API from our implementation */
extern void perla_xs_init(void);

/* ============================================================
 * StradaValue → Perl SV conversion
 * ============================================================ */

static SV* sv_from_strada(StradaValue *stv) {
    if (!stv) return &PL_sv_undef;

    if (STRADA_SV_IS_TAGGED_INT(stv)) {
        return newSViv((IV)STRADA_SV_TAGGED_INT_VAL(stv));
    }

    /* Check StradaValue type — we access the type field directly */
    /* StradaValue layout: void* sv_any (body), int type, ... */
    /* For safety, use strada_to_str/int/num which handle all types */
    char *s = strada_to_str(stv);
    if (s) {
        SV *sv = newSVpv(s, 0);
        free(s);
        return sv;
    }
    return &PL_sv_undef;
}

/* ============================================================
 * Perl SV → StradaValue conversion
 * ============================================================ */

static StradaValue* strada_from_sv(SV *sv) {
    if (!sv || !SvOK(sv)) return strada_new_undef();

    if (SvIOK(sv)) return strada_new_int((int64_t)SvIV(sv));
    if (SvNOK(sv)) return strada_new_num(SvNV(sv));
    if (SvPOK(sv)) {
        STRLEN len;
        char *pv = SvPV(sv, len);
        return strada_new_str_len(pv, len);
    }
    if (SvROK(sv)) {
        /* Reference — wrap the Perl SV as an opaque pointer in StradaValue */
        SvREFCNT_inc(sv);
        return strada_cpointer_new(sv);
    }
    return strada_new_undef();
}

/* ============================================================
 * Perl SV hash → StradaValue hash ref conversion
 * ============================================================ */

static StradaValue* strada_hash_from_hv(HV *hv) {
    if (!hv) return strada_new_ref(strada_new_hash(), '%');
    /* Iterate HV and build StradaHash */
    StradaValue *sh = strada_new_hash();
    StradaHash *shv = strada_deref_hash(sh);

    hv_iterinit(hv);
    char *key;
    I32 klen;
    SV *val;
    while ((val = hv_iternextsv(hv, &key, &klen)) != NULL) {
        strada_hash_set(shv, key, strada_from_sv(val));
    }
    return strada_new_ref(sh, '%');
}

/* ============================================================
 * Perl SV array → StradaValue array ref conversion
 * ============================================================ */

static StradaValue* strada_array_from_av(AV *av) {
    if (!av) return strada_new_ref(strada_new_array(), '@');
    StradaValue *sa = strada_new_array();
    StradaArray *sav = strada_deref_array(sa);

    SSize_t len = av_len(av) + 1;
    for (SSize_t i = 0; i < len; i++) {
        SV **svp = av_fetch(av, i, 0);
        strada_array_push(sav, svp ? strada_from_sv(*svp) : strada_new_undef());
    }
    return strada_new_ref(sa, '@');
}

/* ============================================================
 * DBI Bridge — opaque handle management
 *
 * We store the Perl DBI handle (SV*) inside a StradaValue CPOINTER.
 * When Perla code passes it back, we extract the Perl SV* and use it.
 * ============================================================ */

static SV* get_perl_dbh(StradaValue *dbh_sv) {
    /* dbh_sv is a StradaValue wrapping a Perl SV* */
    if (!dbh_sv || STRADA_SV_IS_TAGGED_INT(dbh_sv)) return NULL;
    /* The Perl SV* is stored as cpointer value */
    /* We need to access StradaValue->value.ptr without including strada_runtime.h */
    /* Hack: StradaValue struct has type at offset 8 (after body ptr) and cpointer type == 10 */
    /* For now, cast and hope the layout matches */
    return (SV*)((void**)dbh_sv)[3]; /* value.ptr is at offset 24 */
}

/* ============================================================
 * DBI->connect($dsn, $user, $pass)
 * ============================================================ */

StradaValue* perla_xs_dbi_connect(StradaValue *dsn_sv, StradaValue *user_sv, StradaValue *pass_sv) {
    dSP;

    /* Convert StradaValues to Perl SVs */
    SV *dsn = sv_from_strada(dsn_sv);
    SV *user = sv_from_strada(user_sv);
    SV *pass = sv_from_strada(pass_sv);

    /* Push onto Perl stack: DBI->connect($dsn, $user, $pass, \%attrs) */
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv("DBI", 0)));  /* class name */
    XPUSHs(sv_2mortal(dsn));
    XPUSHs(sv_2mortal(user));
    XPUSHs(sv_2mortal(pass));
    /* Empty attrs hash */
    HV *attrs = newHV();
    hv_store(attrs, "RaiseError", 10, newSViv(1), 0);
    XPUSHs(sv_2mortal(newRV_noinc((SV*)attrs)));
    PUTBACK;

    /* Call DBI->connect via call_method */
    SSize_t count = call_method("connect", G_SCALAR);

    SPAGAIN;

    StradaValue *result = strada_new_undef();
    if (count >= 1) {
        SV *dbh = POPs;
        if (SvOK(dbh)) {
            /* Wrap the Perl $dbh in a StradaValue */
            SvREFCNT_inc(dbh);
            result = strada_cpointer_new(dbh);
        }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
}

/* ============================================================
 * $dbh->do($sql, undef, @binds)
 * ============================================================ */

StradaValue* perla_xs_dbi_do(StradaValue *dbh_sv, StradaValue *sql_sv, StradaValue *binds_sv) {
    SV *dbh = get_perl_dbh(dbh_sv);
    if (!dbh) return strada_new_undef();

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    XPUSHs(sv_2mortal(sv_from_strada(sql_sv)));
    XPUSHs(&PL_sv_undef);  /* $attr = undef */
    /* Push bind values if any */
    /* TODO: extract from binds_sv StradaArray */
    PUTBACK;

    SSize_t count = call_method("do", G_SCALAR);
    SPAGAIN;

    StradaValue *result = strada_new_undef();
    if (count >= 1) {
        SV *rv = POPs;
        result = strada_from_sv(rv);
    }

    PUTBACK;
    FREETMPS; LEAVE;
    return result;
}

/* ============================================================
 * $dbh->selectrow_array($sql, undef, @binds)
 * ============================================================ */

StradaValue* perla_xs_dbi_selectrow_array(StradaValue *dbh_sv, StradaValue *sql_sv, StradaValue *binds_sv) {
    SV *dbh = get_perl_dbh(dbh_sv);
    if (!dbh) return strada_new_undef();

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    XPUSHs(sv_2mortal(sv_from_strada(sql_sv)));
    XPUSHs(&PL_sv_undef);
    PUTBACK;

    SSize_t count = call_method("selectrow_array", G_ARRAY);
    SPAGAIN;

    StradaValue *arr = strada_new_array();
    StradaArray *av = strada_deref_array(arr);
    for (SSize_t i = 0; i < count; i++) {
        SV *val = POPs;
        strada_array_push(av, strada_from_sv(val));
    }

    PUTBACK;
    FREETMPS; LEAVE;
    return arr;
}

/* ============================================================
 * $dbh->selectall_arrayref($sql, undef, @binds)
 * ============================================================ */

StradaValue* perla_xs_dbi_selectall_arrayref(StradaValue *dbh_sv, StradaValue *sql_sv, StradaValue *binds_sv) {
    SV *dbh = get_perl_dbh(dbh_sv);
    if (!dbh) return strada_new_ref(strada_new_array(), '@');

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    XPUSHs(sv_2mortal(sv_from_strada(sql_sv)));
    XPUSHs(&PL_sv_undef);
    PUTBACK;

    SSize_t count = call_method("selectall_arrayref", G_SCALAR);
    SPAGAIN;

    StradaValue *result = strada_new_ref(strada_new_array(), '@');
    if (count >= 1) {
        SV *rv = POPs;
        if (SvROK(rv) && SvTYPE(SvRV(rv)) == SVt_PVAV) {
            result = strada_array_from_av((AV*)SvRV(rv));
        }
    }

    PUTBACK;
    FREETMPS; LEAVE;
    return result;
}

/* ============================================================
 * $dbh->prepare($sql)
 * ============================================================ */

StradaValue* perla_xs_dbi_prepare(StradaValue *dbh_sv, StradaValue *sql_sv) {
    SV *dbh = get_perl_dbh(dbh_sv);
    if (!dbh) return strada_new_undef();

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    XPUSHs(sv_2mortal(sv_from_strada(sql_sv)));
    PUTBACK;

    SSize_t count = call_method("prepare", G_SCALAR);
    SPAGAIN;

    StradaValue *result = strada_new_undef();
    if (count >= 1) {
        SV *sth = POPs;
        if (SvOK(sth)) {
            SvREFCNT_inc(sth);
            result = strada_cpointer_new(sth);
        }
    }

    PUTBACK;
    FREETMPS; LEAVE;
    return result;
}

/* ============================================================
 * $sth->execute(@binds)
 * ============================================================ */

StradaValue* perla_xs_dbi_execute(StradaValue *sth_sv, StradaValue *binds_sv) {
    SV *sth = get_perl_dbh(sth_sv);
    if (!sth) return strada_new_undef();

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sth);
    PUTBACK;

    SSize_t count = call_method("execute", G_SCALAR);
    SPAGAIN;

    StradaValue *result = strada_new_undef();
    if (count >= 1) result = strada_from_sv(POPs);

    PUTBACK;
    FREETMPS; LEAVE;
    return result;
}

/* ============================================================
 * $sth->fetchrow_hashref()
 * ============================================================ */

StradaValue* perla_xs_dbi_fetchrow_hashref(StradaValue *sth_sv) {
    SV *sth = get_perl_dbh(sth_sv);
    if (!sth) return strada_new_undef();

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sth);
    PUTBACK;

    SSize_t count = call_method("fetchrow_hashref", G_SCALAR);
    SPAGAIN;

    StradaValue *result = strada_new_undef();
    if (count >= 1) {
        SV *rv = POPs;
        if (SvOK(rv) && SvROK(rv) && SvTYPE(SvRV(rv)) == SVt_PVHV) {
            result = strada_hash_from_hv((HV*)SvRV(rv));
        }
    }

    PUTBACK;
    FREETMPS; LEAVE;
    return result;
}

/* ============================================================
 * $dbh->disconnect()
 * ============================================================ */

void perla_xs_dbi_disconnect(StradaValue *dbh_sv) {
    SV *dbh = get_perl_dbh(dbh_sv);
    if (!dbh) return;

    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    PUTBACK;

    call_method("disconnect", G_VOID | G_DISCARD);

    FREETMPS; LEAVE;
}
