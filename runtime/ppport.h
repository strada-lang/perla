/* ppport.h — Perla shim for Devel::PPPort compatibility */
/* Provides backward-compat macros — most are no-ops in Perla */
#ifndef PERLA_PPPORT_H
#define PERLA_PPPORT_H

/* Version macros */
#ifndef PERL_VERSION_GE
#define PERL_VERSION_GE(r,v,s) 1  /* Pretend we're modern Perl */
#endif
#ifndef PERL_VERSION_LT
#define PERL_VERSION_LT(r,v,s) 0
#endif

/* sv_2pv_nolen — just use strada_to_str equivalent */
#ifndef NEED_sv_2pv_nolen
#define NEED_sv_2pv_nolen
#endif

#endif
