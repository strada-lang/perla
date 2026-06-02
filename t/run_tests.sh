#!/bin/bash
# Run all Perla test files
# Usage: ./perla/t/run_tests.sh [--vm]
#   --vm    Run tests via the Strada VM/interpreter instead of compiling

PERLA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# perla self-detects its own runtime and the system Strada runtime; only set
# STRADA_DIR to override with a Strada source tree (e.g. STRADA_DIR=... make test).
PERLA="$PERLA_DIR/perla"
VM_MODE=""

if [ "$1" = "--vm" ]; then
    VM_MODE="--vm"
    echo "Running in VM mode"
fi

passed=0
failed=0
total=0

for test_file in "$PERLA_DIR"/t/*.pl; do
    name=$(basename "$test_file" .pl)
    total=$((total + 1))

    output=$(ulimit -v 2097152 2>/dev/null; timeout 30 "$PERLA" $VM_MODE "$test_file" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        passed=$((passed + 1))
        echo "[PASS] $name"
    else
        failed=$((failed + 1))
        echo "[FAIL] $name"
        echo "  $output" | head -3
    fi
done

echo ""
echo "========================================"
echo "Tests: $total  Passed: $passed  Failed: $failed"
echo "========================================"

[ $failed -eq 0 ]
