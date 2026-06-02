# Perla — Perl 5 Compiler built on Strada (standalone build)
#
# Builds against the SYSTEM-installed Strada by default (the `strada` /
# `stradac` on your PATH, plus their installed runtime + bundled PCRE2).
# To build against a Strada *source/dev tree* instead, pass STRADA_DIR:
#
#   make                              # use system strada (default)
#   make STRADA_DIR=/path/to/strada   # use a Strada source/dev tree
#
#   make           Build the perla compiler
#   make test      Run the test suite
#   make install   Install to PREFIX (default /usr/local)
#   make clean     Remove build artifacts

# Load configure output if available
-include config.mk

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/perla
ETCDIR ?= $(PREFIX)/etc
SHAREDIR ?= $(PREFIX)/share/perla

# --- Locate Strada -----------------------------------------------------------
# STRADA_DIR unset  -> system strada (from PATH and its install tree)
# STRADA_DIR=/path  -> that Strada source/dev tree
STRADA_DIR ?=
ifeq ($(strip $(STRADA_DIR)),)
  STRADA  := $(shell command -v strada)
  STRADAC := $(shell command -v stradac)
  ifeq ($(strip $(STRADA)),)
    $(error 'strada' not found on PATH — install Strada, or pass STRADA_DIR=/path/to/strada)
  endif
  # <prefix>/bin/strada -> <prefix>/lib/strada
  STRADA_LIB  := $(patsubst %/bin/strada,%/lib/strada,$(STRADA))
  RUNTIME_DIR := $(STRADA_LIB)/runtime
  PCRE2_INC   := $(STRADA_LIB)/vendor/pcre2/src
  PCRE2_A     := $(STRADA_LIB)/vendor/pcre2/libpcre2-8.a
else
  STRADA  := $(STRADA_DIR)/strada
  STRADAC := $(STRADA_DIR)/stradac
  RUNTIME_DIR := $(STRADA_DIR)/runtime
  PCRE2_INC   := $(STRADA_DIR)/vendor/pcre2/src
  PCRE2_A     := $(STRADA_DIR)/vendor/pcre2/libpcre2-8.a
endif
RUNTIME_SRC := $(RUNTIME_DIR)/strada_runtime.c
RUNTIME_OBJ := $(RUNTIME_DIR)/strada_runtime.o

# DEV=1 → -O0 builds. Trades a slower perla binary for dramatically faster
# gcc compile times. Default off.   Usage:  make DEV=1
DEV ?= 0
ifeq ($(DEV),1)
PERLA_OPT = -O0
STRADA_OPT = -O0
$(info === DEV=1: building perla at -O0 ===)
else
PERLA_OPT = -O2
STRADA_OPT =
endif

# TCC_RUNTIME=1 builds the TCC-compatible runtime archive used by perla's
# REPL and -e mode. Off by default.
TCC_RUNTIME ?= 0

CC = gcc
CFLAGS = -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable $(PERLA_OPT) -I$(RUNTIME_DIR)
LDFLAGS = -rdynamic -ldl -lm -lpthread -lssl -lcrypto -lz -lsqlite3

# PCRE2 (bundled static lib shipped with the Strada install/tree)
ifneq ($(wildcard $(PCRE2_A)),)
CFLAGS  += -DHAVE_PCRE2 -DPCRE2_STATIC -I$(PCRE2_INC)
LDFLAGS += $(PCRE2_A)
endif

# Memory-management features (default on; match the main Strada runtime build).
# Perla links the shared runtime/strada_runtime.c, so the cycle collector reclaims
# Perl reference cycles automatically without Scalar::Util::weaken.
HAVE_CYCLE_GC ?= 1
HAVE_ARENA ?= 1
ifeq ($(HAVE_CYCLE_GC),1)
CFLAGS += -DSTRADA_CYCLE_GC
endif
ifeq ($(HAVE_ARENA),1)
CFLAGS += -DSTRADA_ARENA
endif

PERLA_RUNTIME = runtime/perla_stash.c

.PHONY: all clean test test-stash test-vm install uninstall tools

ifeq ($(TCC_RUNTIME),1)
all: perla runtime/perla_runtime.a runtime/perla_runtime_tcc.a perla-cpan
else
all: perla runtime/perla_runtime.a perla-cpan
endif

# perla-cpan (the CPAN module installer) is built by default as part of `all`.
# `make tools` additionally builds perla-xs.
tools: perla-cpan perla-xs

perla-cpan: perla-cpan.strada perla
	$(STRADA) $(STRADA_OPT) perla-cpan.strada -o perla-cpan

perla-xs: perla-xs.strada perla
	$(STRADA) $(STRADA_OPT) perla-xs.strada -o perla-xs

# Pre-built runtime archive (GCC-optimized, for production -c builds).
# Optimization level is controlled by $(PERLA_OPT) via $(CFLAGS); DEV=1 drops to -O0.
#
# We reuse Strada's *prebuilt* strada_runtime.o (the one the strada driver
# links) rather than recompiling strada_runtime.c. This matches the strada
# install (which ships the .o, not necessarily the auxiliary table headers
# strada_runtime.c needs), and avoids redundantly rebuilding the large runtime.
runtime/perla_runtime.a: $(RUNTIME_OBJ) $(PERLA_RUNTIME) runtime/perla_dbi.c runtime/perla_moose_xs.c runtime/perla_xsloader.c runtime/perla_xsloader.h runtime/perla_perl_compat.h
	$(CC) $(CFLAGS) -c $(PERLA_RUNTIME) -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_stash.o
	$(CC) $(CFLAGS) -c runtime/perla_dbi.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_dbi.o
	$(CC) $(CFLAGS) -c runtime/perla_moose_xs.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_moose_xs.o
	$(CC) $(CFLAGS) -c runtime/perla_xsloader.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_xsloader.o
	cp $(RUNTIME_OBJ) runtime/strada_runtime.o
	ar rcs $@ runtime/strada_runtime.o runtime/perla_stash.o runtime/perla_dbi.o runtime/perla_moose_xs.o runtime/perla_xsloader.o

# TCC-compatible runtime archive (for REPL and -e mode)
runtime/perla_runtime_tcc.a: $(RUNTIME_SRC) $(PERLA_RUNTIME) runtime/perla_dbi.c runtime/perla_tcc.h runtime/perla_tcc_inlines.c runtime/perla_xsloader.c runtime/perla_xsloader.h runtime/perla_perl_compat.h
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c $(RUNTIME_SRC) -I$(RUNTIME_DIR) -o runtime/strada_runtime_tcc.o
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c $(PERLA_RUNTIME) -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_stash_tcc.o
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c runtime/perla_dbi.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_dbi_tcc.o
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c runtime/perla_tcc_inlines.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_tcc_inlines.o
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c runtime/perla_moose_xs.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_moose_xs_tcc.o
	$(CC) $(CFLAGS) -fPIC -DSTRADA_NO_TLS -c runtime/perla_xsloader.c -I$(RUNTIME_DIR) -Iruntime -o runtime/perla_xsloader_tcc.o
	ar rcs $@ runtime/strada_runtime_tcc.o runtime/perla_stash_tcc.o runtime/perla_dbi_tcc.o runtime/perla_tcc_inlines.o runtime/perla_moose_xs_tcc.o runtime/perla_xsloader_tcc.o

# Combine library sources
lib/Perla/Combined.strada: lib/Perla/AST.strada lib/Perla/Lexer.strada lib/Perla/Parser.strada lib/Perla/CodeGen.strada lib/Perla/Perla.strada
	cat $^ > $@

# Pre-compiled .o files for the main perla libraries. `strada -M` builds
# each to a sibling .o; `use Perla::X;` from perla.strada then auto-
# detects the fresh .o and skips re-inlining the source. Editing one lib
# rebuilds only its .o, then re-links perla — without re-parsing the
# others (~22k lines of source across AST/Lexer/Parser/CodeGen/StradaGen).
PERLA_LIB_MODS = \
    lib/Perla/AST.o \
    lib/Perla/Lexer.o \
    lib/Perla/Parser.o \
    lib/Perla/StradaGen.o \
    lib/Perla/XS.o \
    lib/Perla/CodeGen.o \
    lib/Perla/Perla.o

# Pre-compiled .o files for the CodeGen sub-modules.
PERLA_CODEGEN_MODS = \
    lib/Perla/CodeGen/Escape.o \
    lib/Perla/CodeGen/FreeVars.o \
    lib/Perla/CodeGen/Collect.o \
    lib/Perla/CodeGen/Predicate.o \
    lib/Perla/CodeGen/Eval.o \
    lib/Perla/CodeGen/Subst.o \
    lib/Perla/CodeGen/Interp.o \
    lib/Perla/CodeGen/Subs.o

# CodeGen sub-modules: package name (Perla::CodeGen::X) matches the nested
# directory layout, so the lib-root auto-deduce works without -L.
lib/Perla/CodeGen/%.o: lib/Perla/CodeGen/%.strada $(STRADAC)
	$(STRADA) $(STRADA_OPT) -M $<

# CodeGen / Perla / Parser / StradaGen need -L pointing at the lib root:
# Perla.strada is the top-level package `Perla` (not Perla::Perla), so the
# auto-deduce that strips `<pkg>.strada` would give `lib/Perla` instead of
# `lib`. CodeGen.o depends on its sub-modules so make builds them first.
lib/Perla/CodeGen.o: lib/Perla/CodeGen.strada $(PERLA_CODEGEN_MODS) $(STRADAC)
	$(STRADA) $(STRADA_OPT) -L lib -M $<
lib/Perla/Perla.o: lib/Perla/Perla.strada lib/Perla/CodeGen.o $(STRADAC)
	$(STRADA) $(STRADA_OPT) -L lib -M $<
lib/Perla/Parser.o: lib/Perla/Parser.strada lib/Perla/AST.o lib/Perla/Lexer.o $(STRADAC)
	$(STRADA) $(STRADA_OPT) -L lib -M $<
lib/Perla/StradaGen.o: lib/Perla/StradaGen.strada lib/Perla/AST.o $(STRADAC)
	$(STRADA) $(STRADA_OPT) -L lib -M $<
lib/Perla/%.o: lib/Perla/%.strada $(STRADAC)
	$(STRADA) $(STRADA_OPT) -L lib -M $<

# Build the compiler. With the .o files pre-built, perla.strada just
# `use`s each package and the linker pulls in the .o — no source inlining.
# perla also links the perla runtime objects (perla_stash/dbi/moose_xs/xsloader)
# and is built -rdynamic (the strada driver detects the dlopen in _jit_run_line),
# so the persistent JIT REPL (`perla --jit-repl`) can dlopen each line's .pm.so
# into this process and have it resolve perla-runtime + stash symbols here.
# (strada_runtime.o is already linked by the driver, so it's NOT relisted.)
perla: perla.strada $(PERLA_LIB_MODS) $(PERLA_CODEGEN_MODS) runtime/perla_runtime.a
	$(STRADA) $(STRADA_OPT) perla.strada -o perla \
	    runtime/perla_stash.o runtime/perla_dbi.o runtime/perla_moose_xs.o runtime/perla_xsloader.o \
	    -l readline -l ssl -l crypto -l mysqlclient -l z -l sqlite3 -D HAVE_READLINE

# Test the C runtime
test-stash: runtime/test_stash.c runtime/perla_stash.c runtime/perla_stash.h $(RUNTIME_OBJ)
	$(CC) $(CFLAGS) -g -O0 -o test_stash runtime/test_stash.c $(PERLA_RUNTIME) $(RUNTIME_SRC) $(LDFLAGS)
	./test_stash
	@rm -f test_stash

test: all
	@bash t/run_tests.sh

test-vm: all
	@bash t/run_tests.sh --vm

# Install
install: perla perla-cpan
	@echo "Installing Perla to $(PREFIX)..."
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(LIBDIR)/Perla
	install -d $(DESTDIR)$(LIBDIR)/runtime
	install -d $(DESTDIR)$(ETCDIR)
	install -d $(DESTDIR)$(SHAREDIR)
	install -m 755 perla $(DESTDIR)$(BINDIR)/perla
	# CPAN module installer (built by default; see `perla-cpan --help`)
	if [ -f perla-cpan ]; then install -m 755 perla-cpan $(DESTDIR)$(BINDIR)/perla-cpan; fi
	if [ -f perla-build ]; then install -m 755 perla-build $(DESTDIR)$(BINDIR)/perla-build; fi
	# Perla library modules
	install -m 644 lib/Perla/AST.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/Lexer.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/Parser.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/CodeGen.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/StradaGen.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/XS.strada $(DESTDIR)$(LIBDIR)/Perla/
	install -m 644 lib/Perla/Perla.strada $(DESTDIR)$(LIBDIR)/Perla/
	# DBI shim
	if [ -f lib/DBI.pm ]; then install -m 644 lib/DBI.pm $(DESTDIR)$(LIBDIR)/; fi
	# Perla runtime (sources + prebuilt archive used when compiling user programs)
	install -m 644 runtime/perla_stash.c runtime/perla_stash.h $(DESTDIR)$(LIBDIR)/runtime/
	if [ -f runtime/perla_dbi.c ]; then install -m 644 runtime/perla_dbi.c $(DESTDIR)$(LIBDIR)/runtime/; fi
	if [ -f runtime/perla_perl_compat.h ]; then install -m 644 runtime/perla_perl_compat.h $(DESTDIR)$(LIBDIR)/runtime/; fi
	if [ -f runtime/perla_xsloader.c ]; then install -m 644 runtime/perla_xsloader.c runtime/perla_xsloader.h $(DESTDIR)$(LIBDIR)/runtime/; fi
	if [ -f runtime/perla_runtime.a ]; then install -m 644 runtime/perla_runtime.a $(DESTDIR)$(LIBDIR)/runtime/; fi
	# Config
	if [ -f perla.conf ]; then \
		install -m 644 perla.conf $(DESTDIR)$(ETCDIR)/perla.conf; \
	elif [ -f perla.conf.default ]; then \
		install -m 644 perla.conf.default $(DESTDIR)$(ETCDIR)/perla.conf; \
	fi
	# perlam (module installer)
	if [ -f perlam.pl ]; then install -m 644 perlam.pl $(DESTDIR)$(SHAREDIR)/; fi
	@echo "Installed to $(PREFIX)"
	@echo "  Binary:  $(BINDIR)/perla"
	@echo "  Library: $(LIBDIR)/"
	@echo "  Runtime: $(LIBDIR)/runtime/"
	@echo "  Config:  $(ETCDIR)/perla.conf"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/perla
	rm -f $(DESTDIR)$(BINDIR)/perla-cpan
	rm -f $(DESTDIR)$(BINDIR)/perla-build
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -f $(DESTDIR)$(ETCDIR)/perla.conf
	rm -rf $(DESTDIR)$(SHAREDIR)

clean:
	rm -f perla perla-cpan perla-xs test_stash
	rm -f lib/Perla/Combined.strada
	rm -f runtime/*.o runtime/*.a
	find lib -name '*.o' -delete
	rm -f config.mk perla.conf
