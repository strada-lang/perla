#!/bin/bash
# Multi-language benchmark: perla (native) vs Strada (native) vs Perl vs PHP vs Node.
# Identical workloads (fib/strings/data/oop), outputs cross-checked. Reports the
# min of 3 runs (total process time, incl. startup). perla & strada are compiled
# -O2 to native binaries; perl/php/node are the system CLIs.
#
# NOTE: the perla VM is intentionally NOT benchmarked (project directive).
#
# Usage:  ./run_all.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PERLA="${PERLA_BIN:-$HERE/../../perla}"
STRADA="${STRADA_BIN:-$HERE/../../../strada/strada}"
export STRADA_DIR="${STRADA_DIR:-$HERE/../../../strada}"
cd "$HERE"

W="fib strings data oop"

bestof() {  # min real seconds over 3 runs
    local best=""
    for r in 1 2 3; do
        local t0 t1 dt
        t0=$(date +%s.%N); "$@" >/dev/null 2>&1; t1=$(date +%s.%N)
        dt=$(awk "BEGIN{print $t1-$t0}")
        if [ -z "$best" ] || awk "BEGIN{exit !($dt<$best)}"; then best=$dt; fi
    done
    printf "%.3f" "$best"
}

echo "Building perla -O2 + strada -O2 native binaries..."
for w in $W; do
    "$PERLA"  -O2 -o "perla_$w"      "$w.pl"           >/dev/null 2>&1 && echo "  perla  ok $w" || echo "  perla  FAIL $w"
    "$STRADA" -O2 -o "strada/bin_$w" "strada/$w.strada" >/dev/null 2>&1 && echo "  strada ok $w" || echo "  strada FAIL $w"
done

echo "Outputs (cross-check):"
for w in $W; do
    a="$(./perla_$w 2>&1)"; s="$(strada/bin_$w 2>&1)"; p="$(perl $w.pl 2>&1)"; h="$(php php/$w.php 2>&1)"; j="$(node js/$w.js 2>&1)"
    if [ "$a" = "$p" ] && [ "$s" = "$p" ] && [ "$h" = "$p" ] && [ "$j" = "$p" ]; then
        echo "  ok   $w: $p"
    else
        echo "  DIFF $w:  perla=$a | strada=$s | perl=$p | php=$h | node=$j"
    fi
done

printf "\n%-9s %9s %9s %9s %9s %9s\n" "workload" "perla(s)" "strada(s)" "perl(s)" "php(s)" "node(s)"
printf "%-9s %9s %9s %9s %9s %9s\n" "--------" "--------" "---------" "------" "-----" "------"
for w in $W; do
    pa=$(bestof "./perla_$w"); st=$(bestof "strada/bin_$w"); pl=$(bestof perl "$w.pl"); ph=$(bestof php "php/$w.php"); nd=$(bestof node "js/$w.js")
    printf "%-9s %9s %9s %9s %9s %9s\n" "$w" "$pa" "$st" "$pl" "$ph" "$nd"
done

rm -f perla_* *.c *.xs.c 2>/dev/null || true
