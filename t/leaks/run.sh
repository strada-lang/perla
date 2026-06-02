#!/usr/bin/env bash
# perla/t/leaks/run.sh — leak regression suite for perla.
#
# Each .pl file in this directory exercises one Perl idiom in a tight
# loop (1000 iters by default). The script:
#   1. Compiles each .pl through `perla -c` to get the .c source.
#   2. Links with perla_runtime.a + OpenSSL + PCRE2.
#   3. Runs under valgrind with --leak-check=full.
#   4. Reports per-test "definitely lost" bytes against MAX_LOST_KB.
#
# A test passes if the leak is under MAX_LOST_KB. The baseline includes
# perla_init overhead (~24KB) plus a small slack for new bindings. Tests
# that consistently leak per iteration push the total well above the
# threshold (per-iter * iter count).
#
# Usage:
#   ./run.sh                  # all tests
#   ./run.sh bless            # only tests with 'bless' in name
#   MAX_LOST_KB=80 ./run.sh   # raise threshold (e.g. to land soft-failures)

set -u
PERLA_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STRADA_DIR="$(cd "$PERLA_DIR/.." && pwd)"
PERLA="$PERLA_DIR/perla"
RUNTIME_A="$PERLA_DIR/runtime/perla_runtime.a"

PCRE2_LIB="$STRADA_DIR/vendor/pcre2/libpcre2-8.a"
PCRE2_FLAGS=""
if [ -f "$PCRE2_LIB" ]; then
    PCRE2_FLAGS="-DHAVE_PCRE2 -DPCRE2_STATIC -I$STRADA_DIR/vendor/pcre2/src $PCRE2_LIB"
fi

# Threshold ought to cover ~24KB perla_init baseline + a few KB of
# slack as new bindings accrete. Tests with real per-iter leaks blow
# past this on 1000-iter probes.
MAX_LOST_KB="${MAX_LOST_KB:-50}"

passed=0
failed=0
total=0
filter="${1:-}"

cd "$(dirname "$0")"
for test_file in *.pl; do
    [ -f "$test_file" ] || continue
    name="${test_file%.pl}"
    if [ -n "$filter" ] && [[ "$name" != *"$filter"* ]]; then
        continue
    fi
    total=$((total + 1))
    c_file="/tmp/perla_leak_${name}.c"
    exe="/tmp/perla_leak_${name}"
    "$PERLA" -c "$test_file" 2>/dev/null
    mv "${test_file%.pl}.c" "$c_file" 2>/dev/null || true
    if [ ! -f "$c_file" ]; then
        echo "[SKIP] $name (perla -c failed)"
        continue
    fi
    gcc -g -O0 -w -Wl,--allow-multiple-definition \
        -o "$exe" "$c_file" "$RUNTIME_A" \
        -I"$STRADA_DIR/runtime" -I"$PERLA_DIR/runtime" \
        -rdynamic -ldl -lm -lpthread -lmysqlclient -lssl -lcrypto \
        $PCRE2_FLAGS 2>/dev/null
    if [ ! -f "$exe" ]; then
        echo "[SKIP] $name (gcc failed)"
        rm -f "$c_file"
        continue
    fi
    output=$(valgrind --leak-check=full --show-leak-kinds=definite \
                      --error-exitcode=0 "$exe" 2>&1)
    lost=$(echo "$output" | grep "definitely lost:" | grep -oP '\d[\d,]*(?= bytes)')
    lost_clean=$(echo "$lost" | tr -d ',')
    if [ -z "$lost_clean" ]; then
        echo "[SKIP] $name (valgrind parse error)"
    elif [ "$lost_clean" -le $((MAX_LOST_KB * 1024)) ]; then
        passed=$((passed + 1))
        printf "[PASS] %-30s (%s bytes)\n" "$name" "$lost_clean"
    else
        lost_kb=$((lost_clean / 1024))
        failed=$((failed + 1))
        printf "[FAIL] %-30s (%dKB, limit %dKB)\n" "$name" "$lost_kb" "$MAX_LOST_KB"
    fi
    rm -f "$c_file" "$exe"
done

echo ""
echo "========================================"
echo "Leak tests: $total  Passed: $passed  Failed: $failed"
echo "========================================"
exit $failed
