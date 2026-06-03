#!/bin/bash
# Perla memory leak test suite
# Compiles each test with GCC+debug, runs under valgrind, reports leaks.
#
# Usage: ./perla/t/leak_tests/run_leak_tests.sh [test_name]
#   Run all tests, or a specific test by name (without .pl)
#
# Requires: valgrind, gcc

PERLA_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STRADA_DIR="$(cd "$PERLA_DIR/.." && pwd)"
PERLA="$PERLA_DIR/perla"
TEST_DIR="$PERLA_DIR/t/leak_tests"

RUNTIME="$STRADA_DIR/runtime/strada_runtime.c"
STASH="$PERLA_DIR/runtime/perla_stash.c"
DBI="$PERLA_DIR/runtime/perla_dbi.c"
MOOSE_XS="$PERLA_DIR/runtime/perla_moose_xs.c"
PCRE2_LIB="$STRADA_DIR/vendor/pcre2/libpcre2-8.a"
PCRE2_FLAGS=""
if [ -f "$PCRE2_LIB" ]; then
    PCRE2_FLAGS="-DHAVE_PCRE2 -DPCRE2_STATIC -I$STRADA_DIR/vendor/pcre2/src $PCRE2_LIB"
fi

# Max allowed "definitely lost" bytes per test
# Baseline init overhead is ~7-40KB depending on test complexity
# (function definitions add stash entries). Tests with functions
# have ~38KB baseline. 50KB threshold catches per-iteration leaks.
MAX_LOST_KB=50  # 50KB threshold

passed=0
failed=0
total=0
filter="$1"

for test_file in "$TEST_DIR"/*.pl; do
    name=$(basename "$test_file" .pl)
    if [ -n "$filter" ] && [ "$name" != "$filter" ]; then
        continue
    fi
    total=$((total + 1))

    # Generate C
    c_file="/tmp/perla_leak_${name}.c"
    exe="/tmp/perla_leak_${name}"

    "$PERLA" -c "$test_file" 2>/dev/null
    mv "${test_file%.pl}.c" "$c_file" 2>/dev/null || true
    if [ ! -f "$c_file" ]; then
        echo "[SKIP] $name (compilation failed)"
        continue
    fi

    # Compile with GCC. Link against perla_runtime.a (pre-built) so
    # we pick up perla_xsloader.o and everything else that's now in
    # the archive without listing each .c by name. Add -lssl/-lcrypto
    # for the OpenSSL symbols pulled in by perla_xsloader / digest code,
    # and -lz/-lsqlite3 for the compress/DBI symbols pulled in when a test
    # `use`s a module (e.g. Hash::Util) that drags in perla_xsloader/perla_dbi.
    gcc -g -O0 -w -Wl,--allow-multiple-definition \
        -o "$exe" "$c_file" "$PERLA_DIR/runtime/perla_runtime.a" \
        -I"$STRADA_DIR/runtime" -I"$PERLA_DIR/runtime" \
        -rdynamic -ldl -lm -lpthread -lmysqlclient -lssl -lcrypto -lz -lsqlite3 \
        $PCRE2_FLAGS 2>/dev/null

    if [ ! -f "$exe" ]; then
        echo "[SKIP] $name (gcc failed)"
        rm -f "$c_file"
        continue
    fi

    # Run under valgrind
    output=$(valgrind --leak-check=full --show-leak-kinds=definite "$exe" 2>&1)
    lost=$(echo "$output" | grep "definitely lost:" | grep -oP '\d[\d,]*(?= bytes)')
    lost_clean=$(echo "$lost" | tr -d ',')

    if [ -z "$lost_clean" ]; then
        echo "[SKIP] $name (valgrind parse error)"
    elif [ "$lost_clean" -le $((MAX_LOST_KB * 1024)) ]; then
        passed=$((passed + 1))
        echo "[PASS] $name (${lost_clean} bytes lost)"
    else
        lost_kb=$((lost_clean / 1024))
        failed=$((failed + 1))
        echo "[FAIL] $name (${lost_kb}KB lost, limit ${MAX_LOST_KB}KB)"
    fi

    rm -f "$c_file" "$exe"
done

echo ""
echo "========================================"
echo "Leak Tests: $total  Passed: $passed  Failed: $failed"
echo "========================================"

exit $failed
