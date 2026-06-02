/*
 * perla_dbi.h — DBI compatibility layer for Perla
 *
 * Implements the 7 core DBI methods used by typical Perl apps,
 * backed by libmysqlclient directly.
 */

#ifndef PERLA_DBI_H
#define PERLA_DBI_H

#include "strada_runtime.h"
#include <mysql/mysql.h>

/* Initialize DBI subsystem */
void perla_dbi_init(void);

/* DBI->connect($dsn, $user, $pass, \%attrs) → blessed $dbh */
StradaValue* perla_dbi_connect(const char *dsn, const char *user, const char *pass);

/* $dbh->disconnect() */
void perla_dbi_disconnect(StradaValue *dbh);

/* $dbh->do($sql, undef, @binds) → rows affected */
StradaValue* perla_dbi_do(StradaValue *dbh, const char *sql, StradaValue *binds);

/* $dbh->selectrow_array($sql, undef, @binds) → @row */
StradaValue* perla_dbi_selectrow_array(StradaValue *dbh, const char *sql, StradaValue *binds);

/* $dbh->selectall_arrayref($sql, undef, @binds) → [[row1], [row2], ...] */
StradaValue* perla_dbi_selectall_arrayref(StradaValue *dbh, const char *sql, StradaValue *binds);

/* $dbh->selectcol_arrayref($sql, undef, @binds) → [val1, val2, ...] */
StradaValue* perla_dbi_selectcol_arrayref(StradaValue *dbh, const char *sql, StradaValue *binds);

/* $dbh->prepare($sql) → $sth */
StradaValue* perla_dbi_prepare(StradaValue *dbh, const char *sql);

/* $sth->execute(@binds) → rows */
StradaValue* perla_dbi_execute(StradaValue *sth, StradaValue *binds);

/* $sth->bind_param($p_num, $value [, $type]) → 1 */
StradaValue* perla_dbi_bind_param(StradaValue *sth, StradaValue *args);

/* $sth->bind_columns(\$col0, \$col1, ...) → 1 */
StradaValue* perla_dbi_bind_columns(StradaValue *sth, StradaValue *args);

/* $sth->fetch — fetch next row, populate bound columns. Returns truthy on success, undef at EOF. */
StradaValue* perla_dbi_fetch(StradaValue *sth);

/* $sth->fetchall_arrayref([$slice]) → arrayref of [arrayrefs|hashrefs] */
StradaValue* perla_dbi_fetchall_arrayref(StradaValue *sth, StradaValue *args);

/* $sth->finish() → 1 */
StradaValue* perla_dbi_finish(StradaValue *sth);

/* $sth->FETCH($attr) → value */
StradaValue* perla_dbi_sth_fetch(StradaValue *sth, const char *attr);

/* $sth->fetchrow_hashref() → \%row or undef */
StradaValue* perla_dbi_fetchrow_hashref(StradaValue *sth);

/* $sth->fetchrow_array() → @row */
StradaValue* perla_dbi_fetchrow_array(StradaValue *sth);

/* $dbh->{AutoCommit}, etc. */
StradaValue* perla_dbi_get_attr(StradaValue *handle, const char *attr);
void perla_dbi_set_attr(StradaValue *handle, const char *attr, StradaValue *val);

#endif /* PERLA_DBI_H */
