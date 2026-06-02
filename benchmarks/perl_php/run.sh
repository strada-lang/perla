#!/bin/bash
# perl_php benchmark suite — perla (compiled native) vs Perl vs PHP.
#
# Identical workloads in each language (outputs verified byte-identical). Reports
# the min of 3 runs (total process time, incl. startup). perla is compiled -O2 to
# a native binary; perl/php are the system CLIs.
#
# Usage:  ./run.sh          (from anywhere)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PERLA="${PERLA_BIN:-$HERE/../../perla}"
[ -x "$PERLA" ] || PERLA="$(command -v perla)"
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

echo "Building perla -O2 native binaries..."
for w in $W; do
    "$PERLA" -O2 -o "bin_$w" "$w.pl" >/dev/null 2>&1 && echo "  ok $w" || echo "  FAIL $w"
done

# Correctness: every language must print the same line.
echo "Verifying outputs match..."
for w in $W; do
    a="$(./bin_$w 2>&1)"; p="$(perl $w.pl 2>&1)"; h="$(php php/$w.php 2>&1)"
    if [ "$a" = "$p" ] && [ "$p" = "$h" ]; then echo "  ok $w: $a"
    else echo "  MISMATCH $w:"; echo "    perla=$a"; echo "    perl =$p"; echo "    php  =$h"; fi
done

printf "\n%-9s %10s %10s %10s   %-22s\n" "workload" "perla(s)" "perl(s)" "php(s)" "perla vs perl / php"
printf "%-9s %10s %10s %10s\n" "--------" "--------" "-------" "------"
for w in $W; do
    pa=$(bestof "./bin_$w"); pl=$(bestof perl "$w.pl"); ph=$(bestof php "php/$w.php")
    spl=$(awk "BEGIN{printf \"%.1fx\",$pl/$pa}"); sph=$(awk "BEGIN{printf \"%.1fx\",$ph/$pa}")
    printf "%-9s %10s %10s %10s   %s perl / %s php\n" "$w" "$pa" "$pl" "$ph" "$spl" "$sph"
done

rm -f bin_* *.c *.xs.c 2>/dev/null || true
