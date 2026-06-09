/*
 * perla_dbi.c — DBI compatibility layer for Perla
 *
 * Implements DBI methods using libmysqlclient directly.
 */

#include "perla_dbi.h"
#include "perla_stash.h"
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <stdio.h>
#include <execinfo.h>
#include <sqlite3.h>
#include <dlfcn.h>

/* DBD backend selector. The handle structs carry one of these so each public
 * perla_dbi_* op can dispatch to the MySQL / SQLite / PostgreSQL backend. */
#define DBI_DRV_MYSQL  0
#define DBI_DRV_SQLITE 1
#define DBI_DRV_PG     2

/* ===== libpq (DBD::Pg) loaded lazily via dlopen ==========================
 * We don't link libpq at build time (libpq-dev need not be installed); the
 * handful of functions we use are dlsym'd from libpq.so.5 on first connect.
 * PGconn/PGresult are opaque. Constants: CONNECTION_OK=0, PGRES_COMMAND_OK=1,
 * PGRES_TUPLES_OK=2. */
static void *(*pq_connectdb)(const char *);
static int   (*pq_status)(void *);
static void  (*pq_finish)(void *);
static char *(*pq_errorMessage)(void *);
static void *(*pq_exec)(void *, const char *);
static void *(*pq_execParams)(void *, const char *, int, const unsigned int *,
                              const char *const *, const int *, const int *, int);
static int   (*pq_resultStatus)(void *);
static int   (*pq_ntuples)(void *);
static int   (*pq_nfields)(void *);
static char *(*pq_fname)(void *, int);
static char *(*pq_getvalue)(void *, int, int);
static int   (*pq_getisnull)(void *, int, int);
static char *(*pq_cmdTuples)(void *);
static void  (*pq_clear)(void *);
static int pg_loaded = -1;

static int pg_load(void) {
    if (pg_loaded >= 0) return pg_loaded;
    void *h = dlopen("libpq.so.5", RTLD_NOW | RTLD_GLOBAL);
    if (!h) h = dlopen("libpq.so", RTLD_NOW | RTLD_GLOBAL);
    if (!h) { pg_loaded = 0; return 0; }
    pq_connectdb     = dlsym(h, "PQconnectdb");
    pq_status        = dlsym(h, "PQstatus");
    pq_finish        = dlsym(h, "PQfinish");
    pq_errorMessage  = dlsym(h, "PQerrorMessage");
    pq_exec          = dlsym(h, "PQexec");
    pq_execParams    = dlsym(h, "PQexecParams");
    pq_resultStatus  = dlsym(h, "PQresultStatus");
    pq_ntuples       = dlsym(h, "PQntuples");
    pq_nfields       = dlsym(h, "PQnfields");
    pq_fname         = dlsym(h, "PQfname");
    pq_getvalue      = dlsym(h, "PQgetvalue");
    pq_getisnull     = dlsym(h, "PQgetisnull");
    pq_cmdTuples     = dlsym(h, "PQcmdTuples");
    pq_clear         = dlsym(h, "PQclear");
    pg_loaded = (pq_connectdb && pq_status && pq_exec && pq_execParams
                 && pq_resultStatus && pq_ntuples && pq_nfields && pq_getvalue
                 && pq_clear && pq_finish) ? 1 : 0;
    return pg_loaded;
}

/* ============================================================
 * Internal: MySQL handle wrapper
 * ============================================================ */

typedef struct {
    MYSQL *conn;
    int auto_commit;
    int raise_error;
    int driver;            /* DBI_DRV_* */
    sqlite3 *sqlite;       /* when driver == DBI_DRV_SQLITE */
    void *pg;              /* PGconn* when driver == DBI_DRV_PG */
    char *errstr;          /* last error message (owned) */
} PerlaDBI_DBH;

typedef struct {
    MYSQL_STMT *stmt;
    MYSQL_RES  *result;   /* For simple queries */
    MYSQL      *conn;     /* Back-reference */
    char       *sql;
    int          driver;          /* DBI_DRV_* */
    sqlite3     *sqlite;          /* back-ref to the connection */
    sqlite3_stmt *sqlite_stmt;    /* prepared statement (SQLite) */
    int          sqlite_ncols;    /* column count after execute */
    int          sqlite_done;     /* sqlite3_step returned DONE */
    void        *pg;              /* PGconn* back-ref (DBD::Pg) */
    void        *pg_res;          /* PGresult* from the last execute */
    int          pg_row;          /* next row index to fetch */
    int          pg_nrows;        /* PQntuples */
    int          pg_ncols;        /* PQnfields */
    /* DBI's `$sth->bind_param(N, value)` stores per-placeholder values
     * which `$sth->execute()` (no args) then uses. Without this, the
     * placeholders survive to MySQL as literal `?` and produce a syntax
     * error. DBIC always pre-binds via _bind_sth_params then calls
     * execute() with no args, so this matters for ANY DBIC query. */
    StradaValue **bound_values;   /* indexed by placeholder N-1 */
    size_t        bound_count;
    size_t        bound_cap;
    /* DBI's `$sth->bind_columns(\$col0, \$col1, ...)` registers scalar
     * refs; subsequent `$sth->fetch` populates the referenced scalars
     * with one row's column values. DBIC's Storage::DBI::Cursor::next
     * uses this to avoid allocating a fresh array per row. */
    StradaValue **bound_cols;     /* scalar refs from bind_columns */
    size_t        bound_cols_count;
    size_t        bound_cols_cap;
    /* Workaround for perla's `\(@arr)` returning a single arrayref
     * instead of N scalar refs: bind to the underlying StradaArray
     * directly and update its slots on fetch. */
    StradaValue  *bound_array_ref;  /* incref'd to keep alive */
    StradaArray  *bound_array_av;
} PerlaDBI_STH;

/* ============================================================
 * DSN Parsing: "DBI:mysql:database=foo;host=bar;port=3306"
 * ============================================================ */

static char* parse_dsn_field(const char *dsn, const char *field) {
    char search[128];
    snprintf(search, sizeof(search), "%s=", field);
    const char *p = strstr(dsn, search);
    if (!p) return strdup("");
    p += strlen(search);
    const char *end = p;
    while (*end && *end != ';' && *end != ' ') end++;
    return strndup(p, end - p);
}

static int parse_dsn_port(const char *dsn) {
    char *port_str = parse_dsn_field(dsn, "port");
    int port = atoi(port_str);
    free(port_str);
    return port ? port : 3306;
}

/* Extract the driver name from "dbi:NAME:..." (defaults to "mysql"). Caller frees. */
static char *dsn_driver_name(const char *dsn) {
    const char *p = dsn;
    if (p && strncasecmp(p, "dbi:", 4) == 0) p += 4;
    const char *e = p ? strchr(p, ':') : NULL;
    if (!e) e = p ? p + strlen(p) : NULL;
    size_t nl = (p && e) ? (size_t)(e - p) : 0;
    return nl > 0 ? strndup(p, nl) : strdup("mysql");
}

static PerlaDBI_DBH* unwrap_dbh(StradaValue *handle);

/* ============================================================
 * DBD::SQLite backend (libsqlite3)
 * ============================================================ */

static void sqlite_bind_one(sqlite3_stmt *st, int idx, StradaValue *v) {
    if (!v || (!STRADA_IS_TAGGED_INT(v) && v->type == STRADA_UNDEF)) {
        sqlite3_bind_null(st, idx);
    } else if (STRADA_IS_TAGGED_INT(v) || v->type == STRADA_INT) {
        sqlite3_bind_int64(st, idx, (sqlite3_int64)strada_to_int(v));
    } else if (v->type == STRADA_NUM) {
        sqlite3_bind_double(st, idx, strada_to_num(v));
    } else {
        char *s = strada_to_str(v);
        sqlite3_bind_text(st, idx, s ? s : "", -1, SQLITE_TRANSIENT);
        free(s);
    }
}

/* Bind placeholder values pulled from the method-arg array starting at offset;
 * if none are present, fall back to bind_param-stored values. */
static void sqlite_bind_args(sqlite3_stmt *st, StradaValue *binds, int offset,
                             PerlaDBI_STH *sth) {
    StradaArray *av = binds ? strada_deref_array(binds) : NULL;
    int n = av ? (int)av->size : 0;
    if (n > offset) {
        int pi = 1;
        for (int i = offset; i < n; i++)
            sqlite_bind_one(st, pi++, av->elements[av->head + i]);
    } else if (sth && sth->bound_count) {
        for (size_t i = 0; i < sth->bound_count; i++)
            sqlite_bind_one(st, (int)i + 1, sth->bound_values[i]);
    }
}

static StradaValue *sqlite_col_value(sqlite3_stmt *st, int i) {
    switch (sqlite3_column_type(st, i)) {
        case SQLITE_INTEGER: return strada_new_int((int64_t)sqlite3_column_int64(st, i));
        case SQLITE_FLOAT:   return strada_new_num(sqlite3_column_double(st, i));
        case SQLITE_NULL:    return strada_new_undef();
        default: {
            const unsigned char *t = sqlite3_column_text(st, i);
            int nb = sqlite3_column_bytes(st, i);
            return strada_new_str_len((const char *)(t ? t : (const unsigned char *)""), (size_t)nb);
        }
    }
}

static void sqlite_set_err(PerlaDBI_DBH *h) {
    if (!h || !h->sqlite) return;
    if (h->errstr) free(h->errstr);
    h->errstr = strdup(sqlite3_errmsg(h->sqlite));
}

static StradaValue *sqlite_dbi_connect(const char *dsn, const char *drvname) {
    char *fname = parse_dsn_field(dsn, "dbname");
    if (!fname || !*fname) { free(fname); fname = parse_dsn_field(dsn, "database"); }
    if (!fname || !*fname) {                 /* bare "dbi:SQLite:<file>" form */
        free(fname);
        const char *p = dsn;
        if (strncasecmp(p, "dbi:", 4) == 0) p += 4;
        const char *c = strchr(p, ':');
        fname = strdup(c ? c + 1 : ":memory:");
        if (!*fname) { free(fname); fname = strdup(":memory:"); }
    }
    sqlite3 *db = NULL;
    int rc = sqlite3_open(fname, &db);
    free(fname);
    if (rc != SQLITE_OK) { if (db) sqlite3_close(db); return strada_new_undef(); }
    sqlite3_busy_timeout(db, 5000);

    PerlaDBI_DBH *dbh = calloc(1, sizeof(PerlaDBI_DBH));
    dbh->driver = DBI_DRV_SQLITE;
    dbh->sqlite = db;
    dbh->auto_commit = 1;
    dbh->raise_error = 1;
    StradaValue *cptr = strada_cpointer_new(dbh);
    StradaValue *hv = strada_new_hash();
    strada_hash_set_take(hv->value.hv, "__dbh", cptr);
    {
        StradaValue *drv = strada_new_hash();
        strada_hash_set_take(drv->value.hv, "Name", strada_new_str(drvname));
        StradaValue *drv_ref = strada_new_ref_take(drv, '%');
        perla_bless(drv_ref, "DBI::dr");
        strada_hash_set_take(hv->value.hv, "Driver", drv_ref);
    }
    strada_hash_set_take(hv->value.hv, "Active", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "AutoCommit", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "RaiseError", STRADA_MAKE_TAGGED_INT(1));
    StradaValue *ref = strada_new_ref_take(hv, '%');
    perla_bless(ref, "DBI::db");
    return ref;
}

/* DBI `do` returns rows affected; 0 must come back as the true "0E0". */
static StradaValue *sqlite_rows_value(int changes) {
    return changes > 0 ? STRADA_MAKE_TAGGED_INT(changes) : strada_new_str("0E0");
}

static StradaValue *sqlite_dbi_do(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    PerlaDBI_DBH *h = unwrap_dbh(dbh_sv);
    if (!h || !h->sqlite) return strada_new_undef();
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(h->sqlite, sql, -1, &st, NULL) != SQLITE_OK) {
        sqlite_set_err(h); return strada_new_undef();
    }
    sqlite_bind_args(st, binds, 3, NULL);    /* do(dbh, sql, attrs, @binds) */
    int rc = sqlite3_step(st);
    int changes = sqlite3_changes(h->sqlite);
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW) { sqlite_set_err(h); return strada_new_undef(); }
    return sqlite_rows_value(changes);
}

static StradaValue *sqlite_dbi_prepare(StradaValue *dbh_sv, const char *sql) {
    PerlaDBI_DBH *h = unwrap_dbh(dbh_sv);
    if (!h || !h->sqlite) return strada_new_undef();
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(h->sqlite, sql, -1, &st, NULL) != SQLITE_OK) {
        sqlite_set_err(h); return strada_new_undef();
    }
    PerlaDBI_STH *sth = calloc(1, sizeof(PerlaDBI_STH));
    sth->driver = DBI_DRV_SQLITE;
    sth->sqlite = h->sqlite;
    sth->sqlite_stmt = st;
    sth->sql = strdup(sql ? sql : "");
    StradaValue *sv = strada_cpointer_new(sth);
    perla_bless(sv, "DBI::st");
    return sv;
}

/* execute: reset, bind, and step once so the cursor sits on row 1 (SELECT) or
 * the statement has run (non-query). */
static StradaValue *sqlite_dbi_execute(PerlaDBI_STH *sth, StradaValue *binds) {
    if (!sth || !sth->sqlite_stmt) return strada_new_undef();
    sqlite3_reset(sth->sqlite_stmt);
    sqlite3_clear_bindings(sth->sqlite_stmt);
    sqlite_bind_args(sth->sqlite_stmt, binds, 1, sth);   /* execute(sth, @binds) */
    sth->sqlite_ncols = sqlite3_column_count(sth->sqlite_stmt);
    int rc = sqlite3_step(sth->sqlite_stmt);
    sth->sqlite_done = (rc != SQLITE_ROW);
    if (rc != SQLITE_ROW && rc != SQLITE_DONE) return strada_new_undef();
    if (sth->sqlite_ncols == 0)                          /* non-query */
        return sqlite_rows_value(sqlite3_changes(sth->sqlite));
    return strada_new_str("0E0");                        /* SELECT: true; fetch reads rows */
}

/* Read the current row's columns into a fresh array, then advance the cursor. */
static StradaValue *sqlite_fetchrow_array(PerlaDBI_STH *sth) {
    if (!sth || !sth->sqlite_stmt || sth->sqlite_done) return strada_new_undef();
    StradaValue *row = strada_new_array();
    StradaArray *av = strada_deref_array(row);
    for (int i = 0; i < sth->sqlite_ncols; i++)
        strada_array_push_take(av, sqlite_col_value(sth->sqlite_stmt, i));
    if (sqlite3_step(sth->sqlite_stmt) != SQLITE_ROW) sth->sqlite_done = 1;
    return row;
}

static StradaValue *sqlite_fetchrow_hashref(PerlaDBI_STH *sth) {
    if (!sth || !sth->sqlite_stmt || sth->sqlite_done) return strada_new_undef();
    StradaValue *hv = strada_new_hash();
    for (int i = 0; i < sth->sqlite_ncols; i++) {
        const char *name = sqlite3_column_name(sth->sqlite_stmt, i);
        strada_hash_set_take(hv->value.hv, name ? name : "", sqlite_col_value(sth->sqlite_stmt, i));
    }
    if (sqlite3_step(sth->sqlite_stmt) != SQLITE_ROW) sth->sqlite_done = 1;
    StradaValue *ref = strada_new_ref_take(hv, '%');
    return ref;
}

/* fetchall_arrayref → [ [row], [row], ... ] (array-of-arrayrefs form). */
static StradaValue *sqlite_fetchall_arrayref(PerlaDBI_STH *sth) {
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    while (sth && sth->sqlite_stmt && !sth->sqlite_done) {
        StradaValue *row = sqlite_fetchrow_array(sth);
        if (!row || (!STRADA_IS_TAGGED_INT(row) && row->type == STRADA_UNDEF)) {
            if (row) strada_decref(row); break;
        }
        strada_array_push_take(oav, strada_new_ref_take(row, '@'));
    }
    return strada_new_ref_take(out, '@');
}

/* Prepare + bind (method args at offset 3) for the select* convenience methods. */
static sqlite3_stmt *sqlite_prep_bind(PerlaDBI_DBH *h, const char *sql, StradaValue *binds) {
    sqlite3_stmt *st = NULL;
    if (!h || !h->sqlite || sqlite3_prepare_v2(h->sqlite, sql, -1, &st, NULL) != SQLITE_OK) {
        if (h) sqlite_set_err(h);
        return NULL;
    }
    sqlite_bind_args(st, binds, 3, NULL);
    return st;
}
static StradaValue *sqlite_selectrow_array(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    sqlite3_stmt *st = sqlite_prep_bind(unwrap_dbh(dbh_sv), sql, binds);
    if (!st) return strada_new_undef();
    StradaValue *row = strada_new_array();
    StradaArray *av = strada_deref_array(row);
    if (sqlite3_step(st) == SQLITE_ROW) {
        int nc = sqlite3_column_count(st);
        for (int i = 0; i < nc; i++) strada_array_push_take(av, sqlite_col_value(st, i));
    }
    sqlite3_finalize(st);
    return row;
}
static StradaValue *sqlite_selectall_arrayref(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    sqlite3_stmt *st = sqlite_prep_bind(unwrap_dbh(dbh_sv), sql, binds);
    if (!st) return strada_new_undef();
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    int nc = sqlite3_column_count(st);
    while (sqlite3_step(st) == SQLITE_ROW) {
        StradaValue *row = strada_new_array();
        StradaArray *rav = strada_deref_array(row);
        for (int i = 0; i < nc; i++) strada_array_push_take(rav, sqlite_col_value(st, i));
        strada_array_push_take(oav, strada_new_ref_take(row, '@'));
    }
    sqlite3_finalize(st);
    return strada_new_ref_take(out, '@');
}
static StradaValue *sqlite_selectcol_arrayref(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    sqlite3_stmt *st = sqlite_prep_bind(unwrap_dbh(dbh_sv), sql, binds);
    if (!st) return strada_new_undef();
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    while (sqlite3_step(st) == SQLITE_ROW)
        strada_array_push_take(oav, sqlite_col_value(st, 0));
    sqlite3_finalize(st);
    return strada_new_ref_take(out, '@');
}

static StradaValue *sqlite_dbi_disconnect(PerlaDBI_DBH *h) {
    if (h && h->sqlite) {
        /* Finalize any statements still open on the connection (plain DBI code
         * rarely calls $sth->finish) so sqlite3_close doesn't return BUSY and
         * leak the whole connection. sqlite3_next_stmt walks them all. */
        sqlite3_stmt *s;
        while ((s = sqlite3_next_stmt(h->sqlite, NULL)) != NULL) sqlite3_finalize(s);
        sqlite3_close(h->sqlite);
        h->sqlite = NULL;
    }
    if (h && h->errstr) { free(h->errstr); h->errstr = NULL; }
    return STRADA_MAKE_TAGGED_INT(1);
}

/* ============================================================
 * DBD::Pg backend (libpq via dlopen)
 * ============================================================ */

/* Rewrite DBI '?' placeholders to PostgreSQL '$1','$2',... (libpq's form),
 * skipping '?' inside single-quoted string literals. Caller frees. */
static char *pg_xlate_placeholders(const char *sql) {
    size_t len = strlen(sql);
    char *out = malloc(len * 3 + 1);     /* worst case "?" -> "$NNN" */
    char *w = out;
    int n = 0, inq = 0;
    for (const char *p = sql; *p; p++) {
        if (*p == '\'') { inq = !inq; *w++ = *p; }
        else if (*p == '?' && !inq) { w += sprintf(w, "$%d", ++n); }
        else *w++ = *p;
    }
    *w = '\0';
    return out;
}

/* Build a libpq conninfo string from a "dbi:Pg:dbname=..;host=..;.." DSN
 * (';' -> ' ') plus user/password. Caller frees. */
static char *pg_build_conninfo(const char *dsn, const char *user, const char *pass) {
    const char *p = dsn;
    if (strncasecmp(p, "dbi:", 4) == 0) p += 4;
    const char *c = strchr(p, ':');           /* skip the driver name */
    const char *rest = c ? c + 1 : p;
    size_t cap = strlen(rest) + (user ? strlen(user) : 0) + (pass ? strlen(pass) : 0) + 64;
    char *out = malloc(cap);
    char *w = out;
    for (const char *q = rest; *q; q++) *w++ = (*q == ';') ? ' ' : *q;
    *w = '\0';
    if (user && *user) { size_t o = strlen(out); snprintf(out + o, cap - o, " user=%s", user); }
    if (pass && *pass) { size_t o = strlen(out); snprintf(out + o, cap - o, " password=%s", pass); }
    return out;
}

static StradaValue *pg_make_dbh(void *conn, const char *drvname) {
    PerlaDBI_DBH *dbh = calloc(1, sizeof(PerlaDBI_DBH));
    dbh->driver = DBI_DRV_PG;
    dbh->pg = conn;
    dbh->auto_commit = 1;
    dbh->raise_error = 1;
    StradaValue *cptr = strada_cpointer_new(dbh);
    StradaValue *hv = strada_new_hash();
    strada_hash_set_take(hv->value.hv, "__dbh", cptr);
    {
        StradaValue *drv = strada_new_hash();
        strada_hash_set_take(drv->value.hv, "Name", strada_new_str(drvname));
        StradaValue *drv_ref = strada_new_ref_take(drv, '%');
        perla_bless(drv_ref, "DBI::dr");
        strada_hash_set_take(hv->value.hv, "Driver", drv_ref);
    }
    strada_hash_set_take(hv->value.hv, "Active", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "AutoCommit", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "RaiseError", STRADA_MAKE_TAGGED_INT(1));
    StradaValue *ref = strada_new_ref_take(hv, '%');
    perla_bless(ref, "DBI::db");
    return ref;
}

static StradaValue *pg_dbi_connect(const char *dsn, const char *user,
                                   const char *pass, const char *drvname) {
    if (!pg_load()) return strada_new_undef();
    char *conninfo = pg_build_conninfo(dsn, user, pass);
    void *conn = pq_connectdb(conninfo);
    free(conninfo);
    if (!conn || pq_status(conn) != 0 /* CONNECTION_OK */) {
        if (conn) pq_finish(conn);
        return strada_new_undef();
    }
    return pg_make_dbh(conn, drvname);
}

/* Collect bound parameter value strings (text) from the method-arg array at
 * `offset`, falling back to bind_param values. Returns a malloc'd array of
 * char* (each strdup'd or NULL); sets *np. Caller frees each + the array. */
static char **pg_collect_params(StradaValue *binds, int offset, PerlaDBI_STH *sth, int *np) {
    StradaArray *av = binds ? strada_deref_array(binds) : NULL;
    int n = av ? (int)av->size : 0;
    char **vals = NULL; int count = 0;
    if (n > offset) {
        count = n - offset;
        vals = calloc(count > 0 ? count : 1, sizeof(char *));
        for (int i = 0; i < count; i++) {
            StradaValue *v = av->elements[av->head + offset + i];
            if (!v || (!STRADA_IS_TAGGED_INT(v) && v->type == STRADA_UNDEF)) vals[i] = NULL;
            else vals[i] = strada_to_str(v);
        }
    } else if (sth && sth->bound_count) {
        count = (int)sth->bound_count;
        vals = calloc(count > 0 ? count : 1, sizeof(char *));
        for (int i = 0; i < count; i++) {
            StradaValue *v = sth->bound_values[i];
            if (!v || (!STRADA_IS_TAGGED_INT(v) && v->type == STRADA_UNDEF)) vals[i] = NULL;
            else vals[i] = strada_to_str(v);
        }
    }
    *np = count;
    return vals;
}
static void pg_free_params(char **vals, int n) {
    if (!vals) return;
    for (int i = 0; i < n; i++) free(vals[i]);
    free(vals);
}

/* Run a query with text params; returns the PGresult (caller PQclears) or NULL. */
static void *pg_run(void *conn, const char *sql, StradaValue *binds, int offset, PerlaDBI_STH *sth) {
    int np = 0;
    char **vals = pg_collect_params(binds, offset, sth, &np);
    void *res;
    if (np > 0)
        res = pq_execParams(conn, sql, np, NULL, (const char *const *)vals, NULL, NULL, 0);
    else
        res = pq_exec(conn, sql);
    pg_free_params(vals, np);
    return res;
}

static StradaValue *pg_col_value(void *res, int row, int col) {
    if (pq_getisnull(res, row, col)) return strada_new_undef();
    const char *t = pq_getvalue(res, row, col);
    return strada_new_str(t ? t : "");
}

static StradaValue *pg_rows_value(void *res) {
    char *ct = pq_cmdTuples(res);
    long n = (ct && *ct) ? atol(ct) : 0;
    return n > 0 ? STRADA_MAKE_TAGGED_INT(n) : strada_new_str("0E0");
}

static StradaValue *pg_dbi_do(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    PerlaDBI_DBH *h = unwrap_dbh(dbh_sv);
    if (!h || !h->pg) return strada_new_undef();
    char *q = pg_xlate_placeholders(sql);
    void *res = pg_run(h->pg, q, binds, 3, NULL);
    free(q);
    if (!res) return strada_new_undef();
    int st = pq_resultStatus(res);
    StradaValue *r = (st == 1 /*COMMAND_OK*/ || st == 2 /*TUPLES_OK*/)
                     ? pg_rows_value(res) : strada_new_undef();
    pq_clear(res);
    return r;
}

static StradaValue *pg_dbi_prepare(StradaValue *dbh_sv, const char *sql) {
    PerlaDBI_DBH *h = unwrap_dbh(dbh_sv);
    if (!h || !h->pg) return strada_new_undef();
    PerlaDBI_STH *sth = calloc(1, sizeof(PerlaDBI_STH));
    sth->driver = DBI_DRV_PG;
    sth->pg = h->pg;
    sth->sql = pg_xlate_placeholders(sql);   /* store with $N placeholders */
    StradaValue *sv = strada_cpointer_new(sth);
    perla_bless(sv, "DBI::st");
    return sv;
}

static StradaValue *pg_dbi_execute(PerlaDBI_STH *sth, StradaValue *binds) {
    if (!sth || !sth->pg || !sth->sql) return strada_new_undef();
    if (sth->pg_res) { pq_clear(sth->pg_res); sth->pg_res = NULL; }
    void *res = pg_run(sth->pg, sth->sql, binds, 1, sth);
    if (!res) return strada_new_undef();
    int st = pq_resultStatus(res);
    if (st != 1 && st != 2) { pq_clear(res); return strada_new_undef(); }
    sth->pg_res = res;
    sth->pg_row = 0;
    sth->pg_nrows = pq_ntuples(res);
    sth->pg_ncols = pq_nfields(res);
    if (st == 1 /*COMMAND_OK, no result set*/) return pg_rows_value(res);
    return strada_new_str("0E0");
}

static StradaValue *pg_fetchrow_array(PerlaDBI_STH *sth) {
    if (!sth || !sth->pg_res || sth->pg_row >= sth->pg_nrows) return strada_new_undef();
    int r = sth->pg_row++;
    StradaValue *row = strada_new_array();
    StradaArray *av = strada_deref_array(row);
    for (int c = 0; c < sth->pg_ncols; c++)
        strada_array_push_take(av, pg_col_value(sth->pg_res, r, c));
    return row;
}

static StradaValue *pg_fetchrow_hashref(PerlaDBI_STH *sth) {
    if (!sth || !sth->pg_res || sth->pg_row >= sth->pg_nrows) return strada_new_undef();
    int r = sth->pg_row++;
    StradaValue *hv = strada_new_hash();
    for (int c = 0; c < sth->pg_ncols; c++) {
        const char *name = pq_fname(sth->pg_res, c);
        strada_hash_set_take(hv->value.hv, name ? name : "", pg_col_value(sth->pg_res, r, c));
    }
    return strada_new_ref_take(hv, '%');
}

static StradaValue *pg_fetchall_arrayref(PerlaDBI_STH *sth) {
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    while (sth && sth->pg_res && sth->pg_row < sth->pg_nrows) {
        StradaValue *row = pg_fetchrow_array(sth);
        if (!row || (!STRADA_IS_TAGGED_INT(row) && row->type == STRADA_UNDEF)) {
            if (row) strada_decref(row); break;
        }
        strada_array_push_take(oav, strada_new_ref_take(row, '@'));
    }
    return strada_new_ref_take(out, '@');
}

/* select* convenience methods (method args at offset 3). */
static void *pg_prep_run(PerlaDBI_DBH *h, const char *sql, StradaValue *binds, int *st_out) {
    if (!h || !h->pg) return NULL;
    char *q = pg_xlate_placeholders(sql);
    void *res = pg_run(h->pg, q, binds, 3, NULL);
    free(q);
    if (!res) return NULL;
    *st_out = pq_resultStatus(res);
    return res;
}
static StradaValue *pg_selectrow_array(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    int st = 0; void *res = pg_prep_run(unwrap_dbh(dbh_sv), sql, binds, &st);
    if (!res) return strada_new_undef();
    StradaValue *row = strada_new_array();
    StradaArray *av = strada_deref_array(row);
    if (pq_ntuples(res) > 0) {
        int nc = pq_nfields(res);
        for (int c = 0; c < nc; c++) strada_array_push_take(av, pg_col_value(res, 0, c));
    }
    pq_clear(res);
    return row;
}
static StradaValue *pg_selectall_arrayref(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    int st = 0; void *res = pg_prep_run(unwrap_dbh(dbh_sv), sql, binds, &st);
    if (!res) return strada_new_undef();
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    int nr = pq_ntuples(res), nc = pq_nfields(res);
    for (int r = 0; r < nr; r++) {
        StradaValue *row = strada_new_array();
        StradaArray *rav = strada_deref_array(row);
        for (int c = 0; c < nc; c++) strada_array_push_take(rav, pg_col_value(res, r, c));
        strada_array_push_take(oav, strada_new_ref_take(row, '@'));
    }
    pq_clear(res);
    return strada_new_ref_take(out, '@');
}
static StradaValue *pg_selectcol_arrayref(StradaValue *dbh_sv, const char *sql, StradaValue *binds) {
    int st = 0; void *res = pg_prep_run(unwrap_dbh(dbh_sv), sql, binds, &st);
    if (!res) return strada_new_undef();
    StradaValue *out = strada_new_array();
    StradaArray *oav = strada_deref_array(out);
    int nr = pq_ntuples(res);
    for (int r = 0; r < nr; r++) strada_array_push_take(oav, pg_col_value(res, r, 0));
    pq_clear(res);
    return strada_new_ref_take(out, '@');
}
static StradaValue *pg_dbi_disconnect(PerlaDBI_DBH *h) {
    if (h && h->pg) { pq_finish(h->pg); h->pg = NULL; }
    if (h && h->errstr) { free(h->errstr); h->errstr = NULL; }
    return STRADA_MAKE_TAGGED_INT(1);
}

/* ============================================================
 * DBI->connect($dsn, $user, $pass)
 * ============================================================ */

void perla_dbi_init(void) {
    /* Nothing needed — mysql_init handles per-connection init */
}

StradaValue* perla_dbi_connect(const char *dsn, const char *user, const char *pass) {
    /* Driver dispatch: SQLite is handled natively via libsqlite3; everything
     * else falls through to the libmysqlclient path below. */
    {
        char *drv = dsn ? dsn_driver_name(dsn) : strdup("mysql");
        if (strcasecmp(drv, "SQLite") == 0) {
            StradaValue *r = sqlite_dbi_connect(dsn, drv);
            free(drv);
            return r;
        }
        if (strcasecmp(drv, "Pg") == 0 || strcasecmp(drv, "Postgres") == 0
            || strcasecmp(drv, "PgPP") == 0) {
            StradaValue *r = pg_dbi_connect(dsn, user, pass, drv);
            free(drv);
            return r;
        }
        free(drv);
    }
    if (getenv("PERLA_DBI_DEBUG")) {
        fprintf(stderr, "[dbi_connect] dsn=%s user=%s pass=%s\n",
                dsn ? dsn : "(null)", user ? user : "(null)", pass ? "***" : "(null)");
    }
    /* Parse DSN */
    char *database = parse_dsn_field(dsn, "database");
    char *host = parse_dsn_field(dsn, "host");
    int port = parse_dsn_port(dsn);

    /* Connect */
    MYSQL *conn = mysql_init(NULL);
    if (!conn) {
        fprintf(stderr, "DBI connect: mysql_init failed\n");
        free(database); free(host);
        return strada_new_undef();
    }

    /* Enable reconnect */
    int reconnect = 1;
    mysql_options(conn, MYSQL_OPT_RECONNECT, &reconnect);

    if (!mysql_real_connect(conn, host, user, pass, database, port, NULL, 0)) {
        fprintf(stderr, "DBI connect failed: %s\n", mysql_error(conn));
        mysql_close(conn);
        free(database); free(host);
        return strada_new_undef();
    }

    /* Set UTF-8 */
    mysql_set_character_set(conn, "utf8mb4");
    if (getenv("PERLA_DBI_DEBUG")) fprintf(stderr, "DBI: connected to %s:%d/%s\n", host, port, database);

    free(database);
    free(host);

    /* Wrap in StradaValue */
    PerlaDBI_DBH *dbh = calloc(1, sizeof(PerlaDBI_DBH));
    dbh->conn = conn;
    dbh->auto_commit = 1;
    dbh->raise_error = 1;

    /* Wrap CPOINTER in a blessed HASH so DBIC can probe `$dbh->{Driver}`,
     * `$dbh->{Active}`, `$dbh->{AutoCommit}`, `$dbh->{RaiseError}` etc. like
     * real Perl DBI. The actual MYSQL* lives on __dbh; get_mysql() unwraps. */
    StradaValue *cptr = strada_cpointer_new(dbh);
    StradaValue *hv = strada_new_hash();
    strada_hash_set_take(hv->value.hv, "__dbh", cptr);
    /* Driver subhash with Name (wrapped as blessed ref-to-hash) */
    {
        StradaValue *drv = strada_new_hash();
        /* parse the "DBI:NAME:..." prefix to extract NAME */
        const char *p = dsn;
        if (p && strncasecmp(p, "dbi:", 4) == 0) p += 4;
        else if (p && strncasecmp(p, "DBI:", 4) == 0) p += 4;
        const char *e = p ? strchr(p, ':') : NULL;
        if (!e) e = p ? p + strlen(p) : NULL;
        size_t nl = (p && e) ? (size_t)(e - p) : 0;
        char *drvname = NULL;
        if (nl > 0) {
            drvname = strndup(p, nl);
        } else {
            drvname = strdup("mysql");
        }
        strada_hash_set_take(drv->value.hv, "Name", strada_new_str(drvname));
        free(drvname);
        StradaValue *drv_ref = strada_new_ref_take(drv, '%');
        extern StradaValue* perla_bless(StradaValue *sv, const char *pkg);
        perla_bless(drv_ref, "DBI::dr");
        strada_hash_set_take(hv->value.hv, "Driver", drv_ref);
    }
    strada_hash_set_take(hv->value.hv, "Active", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "AutoCommit", STRADA_MAKE_TAGGED_INT(1));
    strada_hash_set_take(hv->value.hv, "RaiseError", STRADA_MAKE_TAGGED_INT(1));
    /* Wrap hash as ref, then bless the ref (perla blesses REFs not targets). */
    StradaValue *ref = strada_new_ref_take(hv, '%');
    extern StradaValue* perla_bless(StradaValue *sv, const char *pkg);
    perla_bless(ref, "DBI::db");
    return ref;
}

/* ============================================================
 * Helper: get MYSQL* from dbh StradaValue
 * ============================================================ */

/* Forward decl — defined below near perla_dbi_get_attr. */
static PerlaDBI_DBH* unwrap_dbh(StradaValue *handle);

static MYSQL* get_mysql(StradaValue *dbh) {
    PerlaDBI_DBH *h = unwrap_dbh(dbh);
    return h ? h->conn : NULL;
}

/* ============================================================
 * Helper: bind parameters into SQL (simple ? replacement)
 * ============================================================ */

/* bind_params: substitute ? placeholders in `sql` with values from
 * `binds`, starting at index `start_idx`. The dispatch sites pass the
 * whole method-arg array (which contains [dbh, sql, attrs, @real_binds]),
 * so callers should pass start_idx=3 to skip the first three slots.
 * Without that offset bind_params was treating dbh/sql/attrs as binds,
 * substituting "HASH(0x...)" or the SQL itself in place of real values
 * — quietly producing the wrong query. */
static char* bind_params_at(const char *sql, StradaValue *binds, size_t start_idx) {
    if (!binds || !sql) return strdup(sql ? sql : "");

    StradaArray *av = strada_deref_array(binds);
    if (!av || av->size <= start_idx) return strdup(sql);

    size_t sql_len = strlen(sql);
    size_t result_cap = sql_len + 64;   /* grows on demand below */
    char *result = malloc(result_cap);
    if (!result) return NULL;
    size_t len = 0;
    size_t bind_idx = start_idx;

    /* Bound values are UNBOUNDED user data (strada_to_str of an arbitrary
     * scalar), so the buffer MUST grow per-write. The old fixed
     * malloc(sql_len*2 + 4096) was sized by the SQL *template* only and
     * overflowed the heap on any bound value larger than the slack (security
     * audit H4). Ensure room for `extra` more bytes (plus the trailing NUL)
     * before each write, doubling as needed. */
    #define BP_ENSURE(extra) do { \
        size_t _need = len + (size_t)(extra) + 1; \
        if (_need > result_cap) { \
            while (result_cap < _need) result_cap *= 2; \
            char *_nb = realloc(result, result_cap); \
            if (!_nb) { free(result); return NULL; } \
            result = _nb; \
        } \
    } while (0)

    for (size_t i = 0; i < sql_len; i++) {
        if (sql[i] == '?' && bind_idx < av->size) {
            StradaValue *val = strada_array_get(av, bind_idx++);
            if (!val || (!STRADA_IS_TAGGED_INT(val) && val->type == STRADA_UNDEF)) {
                BP_ENSURE(4);
                memcpy(result + len, "NULL", 4);
                len += 4;
            } else {
                char *s = strada_to_str(val);
                /* Worst case: every char is a single-quote (doubled), plus the
                 * two surrounding quotes. */
                BP_ENSURE(strlen(s) * 2 + 2);
                result[len++] = '\'';
                for (char *p = s; *p; p++) {
                    if (*p == '\'') result[len++] = '\'';
                    result[len++] = *p;
                }
                result[len++] = '\'';
                free(s);
            }
        } else {
            BP_ENSURE(1);
            result[len++] = sql[i];
        }
    }
    BP_ENSURE(0);
    result[len] = '\0';
    #undef BP_ENSURE
    return result;
}

/* Backwards-compat wrapper: callers that pass a "true binds" array
 * (already without dbh/sql/attrs in front) keep using this. */
static char* bind_params(const char *sql, StradaValue *binds) {
    return bind_params_at(sql, binds, 0);
}

/* ============================================================
 * $dbh->do($sql, undef, @binds)
 * ============================================================ */

StradaValue* perla_dbi_do(StradaValue *dbh, const char *sql, StradaValue *binds) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) return sqlite_dbi_do(dbh, sql, binds); }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) return pg_dbi_do(dbh, sql, binds); }
    MYSQL *conn = get_mysql(dbh);
    if (!conn) {
        fprintf(stderr, "DBI do: no connection\n");
        return strada_new_undef();
    }
    if (getenv("PERLA_DBI_DEBUG")) fprintf(stderr, "DBI: do(%.60s...)\n", sql ? sql : "(null)");

    /* `binds` is the full method-call arg array
     * ([dbh, sql, attrs, ...real_binds]) coming from perla_method_dispatch.
     * Skip the first three slots so we don't substitute the dbh / sql
     * itself / attrs hash in place of real placeholder values. */
    char *bound_sql = bind_params_at(sql, binds, 3);
    int rc = mysql_query(conn, bound_sql);
    free(bound_sql);

    if (rc != 0) {
        fprintf(stderr, "DBI do error: %s\n", mysql_error(conn));
        return strada_new_undef();
    }

    /* DBI `do` returns the affected-row count; 0 rows must come back as the
     * true string "0E0" (not the false integer 0), else `$dbh->do(DDL) or die`
     * and `ok($dbh->do(...))` wrongly treat a 0-row DDL/UPDATE as failure. */
    my_ulonglong aff = mysql_affected_rows(conn);
    if (aff == 0 || aff == (my_ulonglong)-1) return strada_new_str("0E0");
    return STRADA_MAKE_TAGGED_INT((int64_t)aff);
}

/* ============================================================
 * $dbh->selectrow_array($sql, undef, @binds) → @row
 * ============================================================ */

StradaValue* perla_dbi_selectrow_array(StradaValue *dbh, const char *sql, StradaValue *binds) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) return sqlite_selectrow_array(dbh, sql, binds); }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) return pg_selectrow_array(dbh, sql, binds); }
    MYSQL *conn = get_mysql(dbh);
    if (!conn) return strada_new_undef();
    if (getenv("PERLA_DBI_DEBUG")) fprintf(stderr, "DBI: selectrow_array(%.60s...) dbh_type=%d\n", sql ? sql : "(null)", dbh ? (STRADA_IS_TAGGED_INT(dbh) ? -1 : dbh->type) : -2);

    /* `binds` is the full method-call arg array
     * ([dbh, sql, attrs, ...real_binds]) coming from perla_method_dispatch.
     * Skip the first three slots so we don't substitute the dbh / sql
     * itself / attrs hash in place of real placeholder values. */
    char *bound_sql = bind_params_at(sql, binds, 3);
    int rc = mysql_query(conn, bound_sql);
    free(bound_sql);

    if (rc != 0) {
        fprintf(stderr, "DBI selectrow_array error: %s\n", mysql_error(conn));
        return strada_new_undef();
    }

    MYSQL_RES *result = mysql_store_result(conn);
    if (!result) return strada_new_undef();

    MYSQL_ROW row = mysql_fetch_row(result);
    if (!row) {
        mysql_free_result(result);
        return strada_new_undef();
    }

    unsigned int num_fields = mysql_num_fields(result);
    StradaValue *arr = strada_new_array();
    StradaArray *av = strada_deref_array(arr);
    unsigned long *lengths = mysql_fetch_lengths(result);

    for (unsigned int i = 0; i < num_fields; i++) {
        if (row[i]) {
            strada_array_push(av, strada_new_str_len(row[i], lengths[i]));
        } else {
            strada_array_push(av, strada_new_undef());
        }
    }

    mysql_free_result(result);
    return arr;
}

/* ============================================================
 * $dbh->selectall_arrayref($sql, undef, @binds) → [[row], ...]
 * ============================================================ */

StradaValue* perla_dbi_selectall_arrayref(StradaValue *dbh, const char *sql, StradaValue *binds) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) return sqlite_selectall_arrayref(dbh, sql, binds); }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) return pg_selectall_arrayref(dbh, sql, binds); }
    MYSQL *conn = get_mysql(dbh);
    if (!conn) return strada_new_ref(strada_new_array(), '@');

    /* `binds` is the full method-call arg array
     * ([dbh, sql, attrs, ...real_binds]) coming from perla_method_dispatch.
     * Skip the first three slots so we don't substitute the dbh / sql
     * itself / attrs hash in place of real placeholder values. */
    char *bound_sql = bind_params_at(sql, binds, 3);
    int rc = mysql_query(conn, bound_sql);
    free(bound_sql);

    if (rc != 0) {
        fprintf(stderr, "DBI selectall_arrayref error: %s\n", mysql_error(conn));
        return strada_new_ref(strada_new_array(), '@');
    }

    MYSQL_RES *result = mysql_store_result(conn);
    if (!result) return strada_new_ref(strada_new_array(), '@');

    unsigned int num_fields = mysql_num_fields(result);
    StradaValue *rows = strada_new_array();
    StradaArray *rows_av = strada_deref_array(rows);
    MYSQL_ROW row;

    while ((row = mysql_fetch_row(result))) {
        unsigned long *lengths = mysql_fetch_lengths(result);
        StradaValue *row_arr = strada_new_array();
        StradaArray *row_av = strada_deref_array(row_arr);
        for (unsigned int i = 0; i < num_fields; i++) {
            if (row[i]) {
                strada_array_push(row_av, strada_new_str_len(row[i], lengths[i]));
            } else {
                strada_array_push(row_av, strada_new_undef());
            }
        }
        strada_array_push(rows_av, strada_new_ref(row_arr, '@'));
    }

    mysql_free_result(result);
    return strada_new_ref(rows, '@');
}

/* ============================================================
 * $dbh->selectcol_arrayref($sql, undef, @binds) → [val, ...]
 * ============================================================ */

StradaValue* perla_dbi_selectcol_arrayref(StradaValue *dbh, const char *sql, StradaValue *binds) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) return sqlite_selectcol_arrayref(dbh, sql, binds); }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) return pg_selectcol_arrayref(dbh, sql, binds); }
    MYSQL *conn = get_mysql(dbh);
    if (!conn) return strada_new_ref(strada_new_array(), '@');

    /* `binds` is the full method-call arg array
     * ([dbh, sql, attrs, ...real_binds]) coming from perla_method_dispatch.
     * Skip the first three slots so we don't substitute the dbh / sql
     * itself / attrs hash in place of real placeholder values. */
    char *bound_sql = bind_params_at(sql, binds, 3);
    int rc = mysql_query(conn, bound_sql);
    free(bound_sql);

    if (rc != 0) {
        fprintf(stderr, "DBI selectcol error: %s\n", mysql_error(conn));
        return strada_new_ref(strada_new_array(), '@');
    }

    MYSQL_RES *result = mysql_store_result(conn);
    if (!result) return strada_new_ref(strada_new_array(), '@');

    StradaValue *col = strada_new_array();
    StradaArray *col_av = strada_deref_array(col);
    MYSQL_ROW row;

    while ((row = mysql_fetch_row(result))) {
        unsigned long *lengths = mysql_fetch_lengths(result);
        if (row[0]) {
            strada_array_push(col_av, strada_new_str_len(row[0], lengths[0]));
        } else {
            strada_array_push(col_av, strada_new_undef());
        }
    }

    mysql_free_result(result);
    return strada_new_ref(col, '@');
}

/* ============================================================
 * $dbh->prepare($sql) → $sth
 * ============================================================ */

StradaValue* perla_dbi_prepare(StradaValue *dbh, const char *sql) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) return sqlite_dbi_prepare(dbh, sql); }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) return pg_dbi_prepare(dbh, sql); }
    MYSQL *conn = get_mysql(dbh);
    if (!conn) return strada_new_undef();

    if (getenv("PERLA_DBI_TRACE_SQL")) {
        fprintf(stderr, "DBI:prepare SQL=%s\n", sql ? sql : "(null)");
    }
    if (sql && strstr(sql, "me.1 ") && getenv("PERLA_DBI_DEBUG")) {
        fprintf(stderr, "[me.1 trace] depth=%d\n", perla_call_depth);
        for (int i = perla_call_depth - 1; i >= 0; i--) {
            const char *p = perla_call_stack[i].package ? perla_call_stack[i].package : "?";
            const char *s = perla_call_stack[i].subname ? perla_call_stack[i].subname : "?";
            fprintf(stderr, "  perla[%d] %s::%s\n", i, p, s);
        }
        void *bt[40];
        int n = backtrace(bt, 40);
        char **syms = backtrace_symbols(bt, n);
        fprintf(stderr, "[me.1 C-bt]\n");
        for (int i = 0; i < n; i++) fprintf(stderr, "  C[%d] %s\n", i, syms[i]);
        free(syms);
    }
    PerlaDBI_STH *sth = calloc(1, sizeof(PerlaDBI_STH));
    sth->conn = conn;
    sth->sql = strdup(sql);

    StradaValue *sv = strada_cpointer_new(sth);
    /* Bless as DBI::st so the FETCH dispatcher can distinguish a
     * statement handle from a database handle. Without this, the
     * generic FETCH path treats the STH as a DBH and casts its
     * pointer to the wrong struct. */
    perla_bless(sv, "DBI::st");
    return sv;
}

/* ============================================================
 * $sth->bind_param(N, value [, type_or_attr])
 * Stores value at slot N-1; execute() uses these when called with no args.
 * ============================================================ */
StradaValue* perla_dbi_bind_param(StradaValue *sth_sv, StradaValue *args) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth) return strada_new_undef();

    StradaArray *av = args ? strada_deref_array(args) : NULL;
    if (!av || av->size < 3) return strada_new_undef();
    /* args = [sth, p_num, value, ...] */
    StradaValue *pnum_sv = av->elements[av->head + 1];
    StradaValue *val_sv  = av->elements[av->head + 2];
    int64_t pnum = strada_to_int(pnum_sv);
    if (pnum < 1) return strada_new_undef();
    size_t idx = (size_t)(pnum - 1);

    if (idx >= sth->bound_cap) {
        size_t ncap = sth->bound_cap ? sth->bound_cap * 2 : 8;
        while (ncap <= idx) ncap *= 2;
        sth->bound_values = (StradaValue **)realloc(
            sth->bound_values, ncap * sizeof(StradaValue *));
        for (size_t i = sth->bound_cap; i < ncap; i++) sth->bound_values[i] = NULL;
        sth->bound_cap = ncap;
    }
    if (sth->bound_values[idx]) strada_decref(sth->bound_values[idx]);
    sth->bound_values[idx] = val_sv;
    if (val_sv) strada_incref(val_sv);
    if (idx + 1 > sth->bound_count) sth->bound_count = idx + 1;
    if (getenv("PERLA_DBI_TRACE_SQL")) {
        char *vs = val_sv ? strada_to_str(val_sv) : strdup("");
        const char *vt = "?";
        if (!val_sv) vt = "NULL";
        else if (STRADA_IS_TAGGED_INT(val_sv)) vt = "TAGGED_INT";
        else switch (val_sv->type) {
            case 0: vt = "UNDEF"; break;
            case 1: vt = "INT"; break;
            case 2: vt = "NUM"; break;
            case 3: vt = "STR"; break;
            case 4: vt = "ARRAY"; break;
            case 5: vt = "CLOSURE"; break;
            case 6: vt = "HASH"; break;
            case 7: vt = "REF"; break;
            case 8: vt = "CPOINTER"; break;
            default: vt = "OTHER";
        }
        fprintf(stderr, "DBI:bind_param(%lld, %s, type=%s)\n", (long long)pnum, vs, vt);
        free(vs);
    }
    return STRADA_MAKE_TAGGED_INT(1);
}

/* ============================================================
 * $sth->execute(@binds)
 * ============================================================ */

StradaValue* perla_dbi_execute(StradaValue *sth_sv, StradaValue *binds) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();

    if (sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_SQLITE)
        return sqlite_dbi_execute((PerlaDBI_STH*)sth_sv->value.ptr, binds);
    if (sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_PG)
        return pg_dbi_execute((PerlaDBI_STH*)sth_sv->value.ptr, binds);
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth || !sth->conn || !sth->sql) return strada_new_undef();

    /* Free previous result */
    if (sth->result) {
        mysql_free_result(sth->result);
        sth->result = NULL;
    }

    /* `binds` here is the full @_ from the method dispatch: [sth, bind1, ...].
     * Skip element 0 (the receiver) when substituting `?` placeholders.
     * If no execute-time binds were passed AND the sth has pre-bound
     * values from `bind_param`, use those. (DBIC's _bind_sth_params +
     * execute() with no args is the canonical case.) Otherwise pass NULL
     * so bind_params leaves placeholders alone — using the receiver
     * `[sth]` as a bind list would substitute the sth's CPOINTER(0x…)
     * stringification into the first `?` and produce a query like
     * `WHERE col = 'CPOINTER(0x…)'` that matches no rows. */
    StradaValue *real_binds = NULL;
    StradaArray *src_av = binds ? strada_deref_array(binds) : NULL;
    StradaValue *trim_binds = NULL;
    if (src_av && src_av->size > 1) {
        trim_binds = strada_new_array();
        StradaArray *dst_av = strada_deref_array(trim_binds);
        for (size_t i = 1; i < src_av->size; i++) {
            strada_array_push(dst_av, src_av->elements[i]);
        }
        real_binds = trim_binds;
    } else if (sth->bound_count > 0) {
        trim_binds = strada_new_array();
        StradaArray *dst_av = strada_deref_array(trim_binds);
        for (size_t i = 0; i < sth->bound_count; i++) {
            strada_array_push(dst_av, sth->bound_values[i]
                              ? sth->bound_values[i]
                              : strada_new_undef());
        }
        real_binds = trim_binds;
    }

    char *bound_sql = bind_params(sth->sql, real_binds);
    if (getenv("PERLA_DBI_TRACE_SQL")) {
        fprintf(stderr, "DBI:execute SQL=%s\n", bound_sql);
    }
    int rc = mysql_query(sth->conn, bound_sql);
    free(bound_sql);
    if (trim_binds) strada_decref(trim_binds);

    if (rc != 0) {
        fprintf(stderr, "DBI execute error: %s\n", mysql_error(sth->conn));
        if (getenv("PERLA_DBI_DEBUG")) {
            fprintf(stderr, "  SQL: %s\n", sth->sql);
        }
        return strada_new_undef();
    }

    sth->result = mysql_store_result(sth->conn);
    /* Real DBI returns "0E0" (a truthy zero string) on success-but-no-rows
     * — DBIC's `if (!$rv) { throw }` requires the success path to be truthy
     * even when no rows matched. Returning a tagged int 0 was failing
     * `!$rv` and bubbling up as "execute() returned false". */
    int64_t affected = (int64_t)mysql_affected_rows(sth->conn);
    if (affected == 0) return strada_new_str("0E0");
    return STRADA_MAKE_TAGGED_INT(affected);
}

/* ============================================================
 * $sth->fetchrow_hashref()
 * ============================================================ */

StradaValue* perla_dbi_fetchrow_hashref(StradaValue *sth_sv) {
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_SQLITE) return sqlite_fetchrow_hashref((PerlaDBI_STH*)sth_sv->value.ptr); }
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_PG) return pg_fetchrow_hashref((PerlaDBI_STH*)sth_sv->value.ptr); }
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();

    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth || !sth->result) return strada_new_undef();

    MYSQL_ROW row = mysql_fetch_row(sth->result);
    if (!row) return strada_new_undef();

    unsigned int num_fields = mysql_num_fields(sth->result);
    MYSQL_FIELD *fields = mysql_fetch_fields(sth->result);
    unsigned long *lengths = mysql_fetch_lengths(sth->result);

    StradaValue *hash = strada_new_hash();
    StradaHash *hv = strada_deref_hash(hash);

    for (unsigned int i = 0; i < num_fields; i++) {
        StradaValue *val = row[i] ? strada_new_str_len(row[i], lengths[i]) : strada_new_undef();
        strada_hash_set(hv, fields[i].name, val);
    }

    return strada_new_ref(hash, '%');
}

/* ============================================================
 * $sth->fetchrow_array()
 * ============================================================ */

StradaValue* perla_dbi_fetchrow_array(StradaValue *sth_sv) {
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_SQLITE) return sqlite_fetchrow_array((PerlaDBI_STH*)sth_sv->value.ptr); }
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_PG) return pg_fetchrow_array((PerlaDBI_STH*)sth_sv->value.ptr); }
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();

    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth || !sth->result) return strada_new_undef();

    MYSQL_ROW row = mysql_fetch_row(sth->result);
    if (!row) return strada_new_undef();

    unsigned int num_fields = mysql_num_fields(sth->result);
    unsigned long *lengths = mysql_fetch_lengths(sth->result);

    StradaValue *arr = strada_new_array();
    StradaArray *av = strada_deref_array(arr);

    for (unsigned int i = 0; i < num_fields; i++) {
        if (row[i]) {
            strada_array_push(av, strada_new_str_len(row[i], lengths[i]));
        } else {
            strada_array_push(av, strada_new_undef());
        }
    }

    return arr;
}

/* ============================================================
 * $sth->bind_columns(\$col0, \$col1, ...)
 *  -or-
 * $sth->bind_columns(\(@results))   # DBIC's Cursor::next idiom
 *
 * In real Perl, `\(@results)` produces N scalar refs each aliased to
 * an element slot of @results — fetch can write to slot[i] and the
 * outer @results sees the change. perla's parser instead returns a
 * single arrayref `\@results`, so we sniff the args for that pattern
 * and bind to the underlying StradaArray directly.
 *
 * Stored state:
 *  - bound_cols[i] = scalar ref → fetch writes through ref->value.rv
 *  - bound_array_av (set when single-arrayref form used) → fetch writes
 *    into that StradaArray's slots
 * ============================================================ */

StradaValue* perla_dbi_bind_columns(StradaValue *sth_sv, StradaValue *args) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth) return strada_new_undef();

    /* Drop any prior bindings — release refs we hold. */
    if (sth->bound_cols) {
        for (size_t i = 0; i < sth->bound_cols_count; i++) {
            if (sth->bound_cols[i]) strada_decref(sth->bound_cols[i]);
            sth->bound_cols[i] = NULL;
        }
        sth->bound_cols_count = 0;
    }
    sth->bound_array_av = NULL;
    if (sth->bound_array_ref) {
        strada_decref(sth->bound_array_ref);
        sth->bound_array_ref = NULL;
    }

    StradaArray *av = args ? strada_deref_array(args) : NULL;
    if (!av) return STRADA_MAKE_TAGGED_INT(1);

    /* args = [sth, ...]; skip element 0 (the sth). */
    size_t n = av->size > 0 ? av->size - 1 : 0;
    if (n == 0) return STRADA_MAKE_TAGGED_INT(1);

    /* Single-arrayref form (perla's `\(@arr)`) — bind to the array's
     * slots so fetch can update each one in place. */
    if (n == 1) {
        StradaValue *only = av->elements[av->head + 1];
        if (only && !STRADA_IS_TAGGED_INT(only) && only->type == STRADA_REF
            && only->value.rv && only->value.rv->type == STRADA_ARRAY
            && only->value.rv->value.av) {
            strada_incref(only);
            sth->bound_array_ref = only;
            sth->bound_array_av = only->value.rv->value.av;
            return STRADA_MAKE_TAGGED_INT(1);
        }
    }

    /* N scalar refs (real Perl semantics — also reachable if perla's
     * codegen learns to expand `\(LIST)` properly). */
    if (n > sth->bound_cols_cap) {
        size_t ncap = sth->bound_cols_cap ? sth->bound_cols_cap * 2 : 8;
        while (ncap < n) ncap *= 2;
        sth->bound_cols = (StradaValue **)realloc(
            sth->bound_cols, ncap * sizeof(StradaValue *));
        for (size_t i = sth->bound_cols_cap; i < ncap; i++) sth->bound_cols[i] = NULL;
        sth->bound_cols_cap = ncap;
    }

    for (size_t i = 0; i < n; i++) {
        StradaValue *ref = av->elements[av->head + 1 + i];
        if (ref) strada_incref(ref);
        sth->bound_cols[i] = ref;
    }
    sth->bound_cols_count = n;
    return STRADA_MAKE_TAGGED_INT(1);
}

/* ============================================================
 * $sth->fetch — fetch the next row.
 * If bind_columns was called, populate the bound scalar refs and
 * return them as an arrayref (DBI returns the bound arrayref as
 * a truthy value; DBIC's `if ($sth->fetch)` only checks truthiness
 * and reads `@{$self->{_results}}` separately).
 * Returns undef when no more rows.
 * ============================================================ */

StradaValue* perla_dbi_fetch(StradaValue *sth_sv) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth || !sth->result) return strada_new_undef();

    MYSQL_ROW row = mysql_fetch_row(sth->result);
    if (!row) return strada_new_undef();

    unsigned int num_fields = mysql_num_fields(sth->result);
    unsigned long *lengths = mysql_fetch_lengths(sth->result);

    /* If bind_columns gave us a single arrayref (perla's `\(@arr)`
     * idiom), update each slot in that array. The caller's
     * @{$self->{_results}} sees the updates because they share the
     * same underlying StradaArray. */
    if (sth->bound_array_av) {
        StradaArray *bav = sth->bound_array_av;
        size_t n = num_fields;
        for (size_t i = 0; i < n; i++) {
            StradaValue *newval = row[i]
                ? strada_new_str_len(row[i], lengths[i])
                : strada_new_undef();
            strada_array_set(bav, (int64_t)i, newval);
        }
        /* Return a truthy arrayref so `if ($sth->fetch)` works. Use
         * the bound array itself (with an incref) so callers reading
         * the return see the populated values. */
        if (sth->bound_array_ref) strada_incref(sth->bound_array_ref);
        return sth->bound_array_ref ? sth->bound_array_ref
            : strada_new_ref_take(strada_new_array(), '@');
    }

    /* If bind_columns set scalar refs, write each column into them. */
    if (sth->bound_cols_count > 0) {
        size_t n = sth->bound_cols_count;
        if (n > num_fields) n = num_fields;
        for (size_t i = 0; i < n; i++) {
            StradaValue *ref = sth->bound_cols[i];
            if (!ref || STRADA_IS_TAGGED_INT(ref) || ref->type != STRADA_REF) continue;
            StradaValue *newval = row[i]
                ? strada_new_str_len(row[i], lengths[i])
                : strada_new_undef();
            /* Replace the scalar the ref points to. */
            if (ref->value.rv) strada_decref(ref->value.rv);
            ref->value.rv = newval;
        }
        /* Return a truthy arrayref so `if ($sth->fetch)` works. */
        StradaValue *arr = strada_new_array();
        StradaArray *av = strada_deref_array(arr);
        for (size_t i = 0; i < sth->bound_cols_count; i++) {
            StradaValue *ref = sth->bound_cols[i];
            if (ref && !STRADA_IS_TAGGED_INT(ref) && ref->type == STRADA_REF
                && ref->value.rv) {
                strada_incref(ref->value.rv);
                strada_array_push(av, ref->value.rv);
            } else {
                strada_array_push(av, strada_new_undef());
            }
        }
        return strada_new_ref_take(arr, '@');
    }

    /* No bound columns — return an arrayref of values. */
    StradaValue *arr = strada_new_array();
    StradaArray *av = strada_deref_array(arr);
    for (unsigned int i = 0; i < num_fields; i++) {
        if (row[i]) strada_array_push(av, strada_new_str_len(row[i], lengths[i]));
        else strada_array_push(av, strada_new_undef());
    }
    return strada_new_ref_take(arr, '@');
}

/* ============================================================
 * $sth->fetchall_arrayref([$slice, $maxrows])
 * Returns arrayref of arrayrefs (each row's columns), or arrayref of
 * hashrefs if first arg is a hashref. perla supports the bare form (and
 * the documented `{}` slice for hashref rows). DBIC's Cursor::all uses
 * the bare arrayref form heavily.
 * ============================================================ */

StradaValue* perla_dbi_fetchall_arrayref(StradaValue *sth_sv, StradaValue *args) {
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_SQLITE) return sqlite_fetchall_arrayref((PerlaDBI_STH*)sth_sv->value.ptr); }
    { if (sth_sv && !STRADA_IS_TAGGED_INT(sth_sv) && sth_sv->type == STRADA_CPOINTER && sth_sv->value.ptr && ((PerlaDBI_STH*)sth_sv->value.ptr)->driver == DBI_DRV_PG) return pg_fetchall_arrayref((PerlaDBI_STH*)sth_sv->value.ptr); }
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();

    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth || !sth->result) {
        /* Empty result is still a valid 0-row response: return [] not undef. */
        return strada_new_ref_take(strada_new_array(), '@');
    }

    /* Detect the {} slice form by inspecting the first user arg. The
     * dispatch hands us @_ which is [sth, slice?, maxrows?]; element 1
     * is the slice. */
    int want_hash = 0;
    StradaArray *av = args ? strada_deref_array(args) : NULL;
    if (av && av->size > 1) {
        StradaValue *slice = av->elements[av->head + 1];
        if (slice && !STRADA_IS_TAGGED_INT(slice) && slice->type == STRADA_REF
            && slice->value.rv && slice->value.rv->type == STRADA_HASH) {
            want_hash = 1;
        }
    }

    StradaValue *outer = strada_new_array();
    StradaArray *outer_av = strada_deref_array(outer);

    unsigned int num_fields = mysql_num_fields(sth->result);
    MYSQL_FIELD *fields = mysql_fetch_fields(sth->result);

    MYSQL_ROW row;
    while ((row = mysql_fetch_row(sth->result))) {
        unsigned long *lengths = mysql_fetch_lengths(sth->result);
        StradaValue *inner;
        if (want_hash) {
            StradaValue *hv_sv = strada_new_hash();
            StradaHash *hv = strada_deref_hash(hv_sv);
            for (unsigned int i = 0; i < num_fields; i++) {
                StradaValue *cell = row[i]
                    ? strada_new_str_len(row[i], lengths[i])
                    : strada_new_undef();
                strada_hash_set_take(hv, fields[i].name, cell);
            }
            inner = strada_new_ref_take(hv_sv, '%');
        } else {
            StradaValue *iv = strada_new_array();
            StradaArray *iav = strada_deref_array(iv);
            for (unsigned int i = 0; i < num_fields; i++) {
                StradaValue *cell = row[i]
                    ? strada_new_str_len(row[i], lengths[i])
                    : strada_new_undef();
                strada_array_push_take(iav, cell);
            }
            inner = strada_new_ref_take(iv, '@');
        }
        strada_array_push_take(outer_av, inner);
    }

    return strada_new_ref_take(outer, '@');
}

/* ============================================================
 * $sth->finish()
 * ============================================================ */

StradaValue* perla_dbi_finish(StradaValue *sth_sv) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (sth && sth->driver == DBI_DRV_SQLITE) {
        if (sth->sqlite_stmt) { sqlite3_finalize(sth->sqlite_stmt); sth->sqlite_stmt = NULL; }
        sth->sqlite_done = 1;
        return STRADA_MAKE_TAGGED_INT(1);
    }
    if (sth && sth->driver == DBI_DRV_PG) {
        if (sth->pg_res) { pq_clear(sth->pg_res); sth->pg_res = NULL; }
        sth->pg_row = sth->pg_nrows;
        return STRADA_MAKE_TAGGED_INT(1);
    }
    if (sth && sth->result) {
        mysql_free_result(sth->result);
        sth->result = NULL;
    }
    return STRADA_MAKE_TAGGED_INT(1);
}

/* ============================================================
 * $sth->FETCH($attr) — minimal stub returning common attrs.
 * `Active` (1 if result still has rows pending), `NUM_OF_FIELDS`
 * (number of columns in the result). DBIC's Cursor::next reads both.
 * ============================================================ */

StradaValue* perla_dbi_sth_fetch(StradaValue *sth_sv, const char *attr) {
    if (!sth_sv || STRADA_IS_TAGGED_INT(sth_sv) || sth_sv->type != STRADA_CPOINTER)
        return strada_new_undef();
    PerlaDBI_STH *sth = (PerlaDBI_STH*)sth_sv->value.ptr;
    if (!sth) return strada_new_undef();
    if (strcmp(attr, "Active") == 0) {
        return STRADA_MAKE_TAGGED_INT(sth->result ? 1 : 0);
    }
    if (strcmp(attr, "NUM_OF_FIELDS") == 0) {
        if (!sth->result) return STRADA_MAKE_TAGGED_INT(0);
        return STRADA_MAKE_TAGGED_INT((int64_t)mysql_num_fields(sth->result));
    }
    return strada_new_undef();
}

/* ============================================================
 * $dbh->disconnect()
 * ============================================================ */

void perla_dbi_disconnect(StradaValue *dbh) {
    { PerlaDBI_DBH *__h = unwrap_dbh(dbh); if (__h && __h->driver == DBI_DRV_SQLITE) { sqlite_dbi_disconnect(__h); return; } }
    { PerlaDBI_DBH *__hp = unwrap_dbh(dbh); if (__hp && __hp->driver == DBI_DRV_PG) { pg_dbi_disconnect(__hp); return; } }
    MYSQL *conn = get_mysql(dbh);
    if (conn) mysql_close(conn);
}

/* ============================================================
 * Attribute access stubs
 * ============================================================ */

/* `$dbh->FETCH($attr)` — read a DBI handle attribute.
 * DBIC pokes `Active` (is connected?) and `AutoCommit` (is autocommit on?)
 * via the tied-hash FETCH mechanism, so without this DBIC's transaction
 * code dies with `Can't locate object method "FETCH" via package "DBI::db"`. */
/* Walk a DBI handle's wrapper layers to find the underlying CPOINTER.
 * The handle is now ref → blessed-hash → {__dbh => CPOINTER} (after the
 * connect path was rewritten so DBIC can probe `$dbh->{Driver}{Name}` etc).
 * Older callers may still pass plain CPOINTER or REF→CPOINTER directly. */
static PerlaDBI_DBH* unwrap_dbh(StradaValue *handle) {
    if (!handle || STRADA_IS_TAGGED_INT(handle)) return NULL;
    StradaValue *h = handle;
    while (h && !STRADA_IS_TAGGED_INT(h) && h->type == STRADA_REF && h->value.rv) h = h->value.rv;
    if (!h || STRADA_IS_TAGGED_INT(h)) return NULL;
    if (h->type == STRADA_CPOINTER && h->value.ptr) return (PerlaDBI_DBH*)h->value.ptr;
    if (h->type == STRADA_HASH) {
        StradaValue *inner = strada_hash_get(h->value.hv, "__dbh");
        if (inner && !STRADA_IS_TAGGED_INT(inner)) {
            while (inner && !STRADA_IS_TAGGED_INT(inner) && inner->type == STRADA_REF && inner->value.rv) inner = inner->value.rv;
            if (inner && !STRADA_IS_TAGGED_INT(inner) && inner->type == STRADA_CPOINTER && inner->value.ptr) {
                return (PerlaDBI_DBH*)inner->value.ptr;
            }
        }
    }
    return NULL;
}

StradaValue* perla_dbi_get_attr(StradaValue *handle, const char *attr) {
    if (!handle || STRADA_IS_TAGGED_INT(handle) || !attr) return strada_new_undef();
    PerlaDBI_DBH *d = unwrap_dbh(handle);
    if (!d) return strada_new_undef();
    if (strcmp(attr, "Active") == 0) {
        return STRADA_MAKE_TAGGED_INT(d->conn ? 1 : 0);
    } else if (strcmp(attr, "AutoCommit") == 0) {
        return STRADA_MAKE_TAGGED_INT(d->auto_commit ? 1 : 0);
    } else if (strcmp(attr, "RaiseError") == 0) {
        return STRADA_MAKE_TAGGED_INT(d->raise_error ? 1 : 0);
    }
    return strada_new_undef();
}

void perla_dbi_set_attr(StradaValue *handle, const char *attr, StradaValue *val) {
    if (!handle || STRADA_IS_TAGGED_INT(handle) || !attr) return;
    PerlaDBI_DBH *d = unwrap_dbh(handle);
    if (!d) return;
    int v = val ? (int)strada_to_int(val) : 0;
    if (strcmp(attr, "AutoCommit") == 0) d->auto_commit = v ? 1 : 0;
    else if (strcmp(attr, "RaiseError") == 0) d->raise_error = v ? 1 : 0;
    /* Other attrs silently ignored. */
}

/* `$dbh->get_info($info_type)` — DBI's portable per-driver info lookup.
 * MySQL via libmysqlclient: hard-code the values DBIC actually looks at,
 * return undef for everything else (DBIC has try{} around get_info in
 * many places and falls back to safer defaults). The numeric codes match
 * the ones in DBI::Const::GetInfoType — this mirrors what DBD::mysql
 * returns. */
StradaValue* perla_dbi_get_info(StradaValue *handle, int info_type) {
    PerlaDBI_DBH *d = unwrap_dbh(handle);
    switch (info_type) {
        case 17:  /* SQL_DBMS_NAME */ return strada_new_str("MySQL");
        case 18: { /* SQL_DBMS_VER */
            if (d && d->conn) {
                const char *v = mysql_get_server_info(d->conn);
                return strada_new_str(v ? v : "");
            }
            return strada_new_str("");
        }
        case 28: /* SQL_IDENTIFIER_CASE */         return STRADA_MAKE_TAGGED_INT(2);
        case 29: /* SQL_IDENTIFIER_QUOTE_CHAR */   return strada_new_str("`");
        case 41: /* SQL_CATALOG_NAME_SEPARATOR */  return strada_new_str(".");
        case 86: /* SQL_NON_NULLABLE_COLUMNS */    return STRADA_MAKE_TAGGED_INT(1);
        case 114: /* SQL_CATALOG_LOCATION */       return STRADA_MAKE_TAGGED_INT(1);
        case 116: /* SQL_QUOTED_IDENTIFIER_CASE */ return STRADA_MAKE_TAGGED_INT(2);
        default:                                   return strada_new_undef();
    }
}
