#!/bin/bash
# Build + run the Phase 0 REPL-JIT harness against the system Strada runtime.
set -e
cd "$(dirname "$0")"

# Locate the Strada runtime the same way perla does (system install by default).
SB="$(command -v strada || true)"
if [ -n "$SB" ]; then
    RT="$(cd "$(dirname "$SB")/.." && pwd)/lib/strada"
else
    RT="/usr/local/lib/strada"
fi
RUNTIME_DIR="$RT/runtime"
PCRE2_INC="$RT/vendor/pcre2/src"
PCRE2_A="$RT/vendor/pcre2/libpcre2-8.a"

PCRE2_ARGS=()
[ -f "$PCRE2_A" ] && PCRE2_ARGS=(-DHAVE_PCRE2 -DPCRE2_STATIC -I"$PCRE2_INC" "$PCRE2_A")

# Host links the strada runtime and exports its + the pad's symbols (-rdynamic)
# so each dlopen'd snippet resolves them.
gcc -O0 -w -I"$RUNTIME_DIR" -DRUNTIME_INC="\"$RUNTIME_DIR\"" \
    -DSTRADA_CYCLE_GC -DSTRADA_ARENA -rdynamic \
    -o host host.c "$RUNTIME_DIR/strada_runtime.o" \
    "${PCRE2_ARGS[@]}" \
    -ldl -lm -lpthread -lssl -lcrypto -lz -lsqlite3

echo "built ./host"
./host
