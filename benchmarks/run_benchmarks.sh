#!/bin/bash
# Perla vs Perl Benchmark Runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PERLA_DIR="$(dirname "$SCRIPT_DIR")"
STRADA_DIR="$(dirname "$PERLA_DIR")"
PERLA="$PERLA_DIR/perla"

printf "%-20s %10s %10s %10s %8s %8s\n" "Benchmark" "Perl" "Perla" "VM" "Comp." "VM"
printf "%-20s %10s %10s %10s %8s %8s\n" "---------" "----" "-----" "--" "ratio" "ratio"

for bench in "$SCRIPT_DIR"/bench_*.pl; do
    name=$(basename "$bench" .pl | sed 's/bench_//')

    # Perl timing
    perl_time=$( { time perl "$bench" >/dev/null 2>&1 ; } 2>&1 | grep real | sed 's/real\t//' | sed 's/0m//' | sed 's/s//')

    # Perla compile + run (-o builds an executable; -c only emits C)
    cd "$SCRIPT_DIR"
    exe="./bench_${name}"
    STRADA_DIR="$STRADA_DIR" "$PERLA" -o "$exe" "$bench" >/dev/null 2>&1
    perla_time="n/a"
    if [ -x "$exe" ]; then
        perla_time=$( { time "$exe" >/dev/null 2>&1 ; } 2>&1 | grep real | sed 's/real\t//' | sed 's/0m//' | sed 's/s//')
        rm -f "$exe" "bench_${name}.c" *.xs.c 2>/dev/null
    fi

    # Perla VM timing
    vm_time="n/a"
    vm_out=$( { time STRADA_DIR="$STRADA_DIR" "$PERLA" --vm "$bench" >/dev/null 2>&1 ; } 2>&1)
    vm_rc=$?
    if [ $vm_rc -eq 0 ]; then
        vm_time=$(echo "$vm_out" | grep real | sed 's/real\t//' | sed 's/0m//' | sed 's/s//')
    fi

    # Calculate ratios
    comp_ratio="n/a"
    if [ "$perla_time" != "n/a" ] && [ "$perl_time" != "0.000" ]; then
        comp_ratio=$(echo "scale=1; $perla_time / $perl_time" | bc 2>/dev/null || echo "n/a")
    fi
    vm_ratio="n/a"
    if [ "$vm_time" != "n/a" ] && [ "$perl_time" != "0.000" ]; then
        vm_ratio=$(echo "scale=1; $vm_time / $perl_time" | bc 2>/dev/null || echo "n/a")
    fi

    printf "%-20s %10s %10s %10s %7sx %7sx\n" "$name" "${perl_time}s" "${perla_time}s" "${vm_time}s" "$comp_ratio" "$vm_ratio"
done
