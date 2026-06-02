/*
 * perla_tcc.h - Combined header for TCC compilation of Perla programs
 *
 * This header replaces both strada_runtime.h and perla_stash.h when
 * compiling with TCC. It uses strada_runtime_tcc.h (which avoids
 * system headers TCC can't parse) and adds perla-specific declarations.
 */
#ifndef PERLA_TCC_H
#define PERLA_TCC_H

#include "strada_runtime_tcc.h"

/* StradaClosure — needed for coderef calls in generated code */
typedef struct StradaClosure {
    void *func_ptr;
    int param_count;
    int capture_count;
    StradaValue ***captures;
} StradaClosure;

/* ===== C stdlib declarations needed by generated Perla code ===== */
/* These may not be in strada_runtime_tcc.h */
#ifndef RTLD_DEFAULT
#define RTLD_DEFAULT ((void *)0)
#endif
#ifndef RTLD_NOW
#define RTLD_NOW 0x00002
#endif
#ifndef RTLD_GLOBAL
#define RTLD_GLOBAL 0x00100
#endif

/* Only declare if not already provided by strada_runtime_tcc.h */
#ifndef _PERLA_TCC_STDLIB
#define _PERLA_TCC_STDLIB
extern char *strchr(const char *s, int c);
extern char *strrchr(const char *s, int c);
extern char *strdup(const char *s);
extern char *strndup(const char *s, size_t n);
extern void *dlopen(const char *filename, int flags);
extern void *dlsym(void *handle, const char *symbol);
extern char *dlerror(void);
extern int dlclose(void *handle);
extern int unlink(const char *pathname);
extern int getpid(void);
extern long readlink(const char *pathname, char *buf, size_t bufsiz);

/* stdio functions needed by generated code */
extern FILE *stderr;
extern FILE *stdout;
extern FILE *stdin;
extern int fprintf(FILE *stream, const char *format, ...);
extern int snprintf(char *str, size_t size, const char *format, ...);
extern int sprintf(char *str, const char *format, ...);

/* string functions */
extern int strcmp(const char *s1, const char *s2);
extern int strncmp(const char *s1, const char *s2, size_t n);
extern size_t strlen(const char *s);
extern char *strstr(const char *haystack, const char *needle);
extern void *memcpy(void *dest, const void *src, size_t n);
extern void *memset(void *s, int c, size_t n);
extern int memcmp(const void *s1, const void *s2, size_t n);
extern void *memchr(const void *s, int c, size_t n);

/* time functions */
struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};
typedef long time_t;
extern time_t time(time_t *tloc);
extern struct tm *localtime(const time_t *timep);
extern struct tm *gmtime(const time_t *timep);
extern size_t strftime(char *s, size_t max, const char *format, const struct tm *tm);
extern time_t mktime(struct tm *tm);

/* directory operations */
typedef void DIR;
struct dirent {
    unsigned long d_ino;
    unsigned short d_reclen;
    unsigned char d_type;
    char d_name[256];
};
extern DIR *opendir(const char *name);
extern struct dirent *readdir(DIR *dirp);
extern int closedir(DIR *dirp);

/* file system */
struct stat {
    unsigned long st_dev;
    unsigned long st_ino;
    unsigned int st_mode;
    unsigned long st_nlink;
    unsigned int st_uid;
    unsigned int st_gid;
    unsigned long st_rdev;
    long st_size;
    long st_blksize;
    long st_blocks;
    long st_atime;
    long st_atimensec;
    long st_mtime;
    long st_mtimensec;
    long st_ctime;
    long st_ctimensec;
    long __unused[3];
};
extern int stat(const char *pathname, struct stat *statbuf);
extern int fstat(int fd, struct stat *statbuf);
extern int lstat(const char *pathname, struct stat *statbuf);
extern int mkdir(const char *pathname, unsigned int mode);
extern int rmdir(const char *pathname);
extern int rename(const char *oldpath, const char *newpath);
extern int chmod(const char *pathname, unsigned int mode);

/* errno */
extern int errno;
extern char *strerror(int errnum);

/* process */
extern char *getenv(const char *name);
extern int setenv(const char *name, const char *value, int overwrite);
extern int system(const char *command);
extern unsigned int sleep(unsigned int seconds);

/* math */
extern double sqrt(double x);
extern double pow(double x, double y);
extern double fabs(double x);
extern double floor(double x);
extern double ceil(double x);
extern double fmod(double x, double y);
extern double log(double x);
extern double exp(double x);
extern double sin(double x);
extern double cos(double x);
#endif

/* ===== Perla Stash API ===== */

/* Forward declarations for perla runtime functions */
/* These are implemented in perla_stash.c (precompiled into .a) */

typedef struct PerlGlob {
    StradaValue *slots[6];
    char *name;
    char *fullname;
} PerlGlob;

typedef struct PerlStash {
    char *name;
    PerlGlob **entries;
    char **keys;
    int count;
    int capacity;
    StradaValue *isa;
} PerlStash;

#define PERLA_SLOT_SCALAR  0
#define PERLA_SLOT_ARRAY   1
#define PERLA_SLOT_HASH    2
#define PERLA_SLOT_CODE    3
#define PERLA_SLOT_IO      4
#define PERLA_SLOT_FORMAT  5
#define PERLA_SLOT_COUNT   6

/* Initialization */
void perla_init(void);
void perla_cleanup(void);
void perla_dbi_init(void);

/* Stash management */
PerlStash *perla_stash_get(const char *pkg);
PerlStash *perla_stash_get_or_create(const char *pkg);

/* Glob management */
PerlGlob *perla_glob_get(PerlStash *stash, const char *name);
PerlGlob *perla_glob_get_or_create(PerlStash *stash, const char *name);
void perla_glob_assign(PerlGlob *glob, StradaValue *val);

/* Hash access (implemented in perla_tcc_inlines.c) */
void strada_hv_store(StradaValue *sv, const char *key, StradaValue *val);
void strada_hv_store_take(StradaValue *sv, const char *key, StradaValue *val);
StradaValue *strada_hv_fetch_owned(StradaValue *sv, const char *key);

/* Code/method registry */
StradaValue *perla_code_get(const char *pkg, const char *name);
void perla_code_set(const char *pkg, const char *name, StradaValue *val);
StradaValue *perla_call_code(StradaValue *code_val, StradaValue *args);
void perla_mark_loaded(const char *module);
void perla_init_moose_stubs(void);
StradaValue *perla_moose_import(StradaValue *args);
StradaValue *perla_moose_role_import(StradaValue *args);
StradaValue *perla_throw_exception(StradaValue *args);

/* Method dispatch */
StradaValue *perla_method_dispatch(StradaValue *obj, const char *method, StradaValue *args);
StradaValue *perla_super_dispatch(StradaValue *obj, const char *current_pkg, const char *method, StradaValue *args);
StradaValue *perla_next_method_dispatch(StradaValue *obj, StradaValue *args, int maybe);
StradaValue *perla_try_autoload(const char *pkg, const char *method, StradaValue *obj, StradaValue *args);

/* ISA / inheritance */
StradaValue *perla_isa_get(const char *pkg);
void perla_isa_push(const char *pkg, const char *parent);
int perla_isa_check(const char *pkg, const char *target);

/* Introspection */
const char *perla_blessed(StradaValue *ref);
StradaValue *perla_bless(StradaValue *ref, const char *pkg);
int perla_to_bool(StradaValue *sv);
int perla_can(const char *pkg, const char *method);
StradaValue *perla_can_code(const char *pkg, const char *method);

/* Global-destruction DESTROY sweep */
void perla_blessed_registry_add(StradaValue *ref);
void perla_destroy_sweep(void);
int perla_in_global_destruction_active(void);

/* eval STRING */
void perla_eval_set_paths(const char *perla_path, const char *strada_dir);
StradaValue *perla_eval_string(StradaValue *code_sv, const char *current_pkg);

/* Call stack */
#define PERLA_CALL_STACK_SIZE 256
typedef struct {
    const char *package;
    const char *subname;
    const char *file;
    int line;
} PerlaCallFrame;
extern PerlaCallFrame perla_call_stack[PERLA_CALL_STACK_SIZE];
extern int perla_call_depth;
void perla_call_push(const char *pkg, const char *sub, const char *file, int line);
void perla_call_pop(void);
StradaValue *perla_caller(int level);

/* Runtime require */
StradaValue *perla_require_module(StradaValue *module_sv);

/* Data::Dumper */
StradaValue *perla_dumper(StradaValue *args);

/* Dynamic glob assignment */
StradaValue *perla_glob_assign_dynamic(StradaValue *name_sv, StradaValue *val);
StradaValue *perla_glob_assign_dynamic_pkg(StradaValue *name_sv, StradaValue *val, const char *default_pkg);

/* Sort */
typedef StradaValue* (*perla_cmp_func)(StradaValue *args);
StradaValue* perla_sort_custom(StradaValue *arr, void *cmp_fn);

/* local-chain (block-scoped local restore) */
void *perla_local_push_hash_elem(void *chain, StradaValue *hashref,
                                 StradaValue *key_sv, StradaValue *new_val);
void *perla_local_push_array_elem(void *chain, StradaValue *arrayref,
                                  int idx, StradaValue *new_val);
void *perla_local_push_scalar_slot(void *chain, StradaValue **slot,
                                   StradaValue *new_val);
void *perla_local_push_scalar_slot_m(void *chain, StradaValue **slot,
                                     StradaValue *new_val,
                                     StradaValue **mirror);
void perla_local_chain_restore_all(void *chain);
void perla_local_chain_restore_to(void *chain, void *marker);
extern void *__perla_local_chain;

/* each @arr — perla-side iterator (strada has no array-each) */
StradaValue *perla_array_each(StradaArray *av);

/* caller() line tracking — codegen sets at each call site; perla_call_push
 * consumes into the new frame's `line` field. */
extern int perla_pending_call_line;

/* DBI stubs (may not be available) */
StradaValue *perla_dbi_connect(StradaValue *args);
StradaValue *perla_dbi_do(StradaValue *args);
StradaValue *perla_dbi_prepare(StradaValue *args);
StradaValue *perla_dbi_execute(StradaValue *args);
StradaValue *perla_dbi_fetchrow_hashref(StradaValue *args);
StradaValue *perla_dbi_fetchrow_array(StradaValue *args);
StradaValue *perla_dbi_selectrow_array(StradaValue *args);
StradaValue *perla_dbi_selectall_arrayref(StradaValue *args);
StradaValue *perla_dbi_selectcol_arrayref(StradaValue *args);
StradaValue *perla_dbi_disconnect(StradaValue *args);

#endif /* PERLA_TCC_H */
