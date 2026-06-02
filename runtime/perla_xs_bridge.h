/*
 * perla_xs_bridge.h — Bridge between StradaValue and Perl SV for XS modules
 *
 * Provides conversion functions and DBI method wrappers that
 * Perla-generated code can call directly.
 */

#ifndef PERLA_XS_BRIDGE_H
#define PERLA_XS_BRIDGE_H

#include "strada_runtime.h"

/* Initialize XS subsystem (boots DBI + DBD::mysql) */
void perla_xs_init(void);

/* DBI->connect($dsn, $user, $pass) */
StradaValue* perla_xs_dbi_connect(StradaValue *dsn, StradaValue *user, StradaValue *pass);

/* $dbh->do($sql, $attr, @binds) */
StradaValue* perla_xs_dbi_do(StradaValue *dbh_sv, StradaValue *sql, StradaValue *binds);

/* $dbh->selectrow_array($sql, $attr, @binds) */
StradaValue* perla_xs_dbi_selectrow_array(StradaValue *dbh_sv, StradaValue *sql, StradaValue *binds);

/* $dbh->selectall_arrayref($sql, $attr, @binds) */
StradaValue* perla_xs_dbi_selectall_arrayref(StradaValue *dbh_sv, StradaValue *sql, StradaValue *binds);

/* $dbh->prepare($sql) */
StradaValue* perla_xs_dbi_prepare(StradaValue *dbh_sv, StradaValue *sql);

/* $sth->execute(@binds) */
StradaValue* perla_xs_dbi_execute(StradaValue *sth_sv, StradaValue *binds);

/* $sth->fetchrow_hashref() */
StradaValue* perla_xs_dbi_fetchrow_hashref(StradaValue *sth_sv);

/* $dbh->disconnect() */
void perla_xs_dbi_disconnect(StradaValue *dbh_sv);

#endif
