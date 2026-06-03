#!/usr/bin/env bash
# safe_run.sh - cap aggregate RSS, fork count, and wall time for compile/run
# commands via systemd-run --scope (cgroup-enforced).
#
# Usage:
#   ./safe_run.sh [--timeout SEC] [--mem SIZE] [--tasks N] -- CMD [ARGS...]
#
# Defaults: --timeout 600 (10 min), --mem 6G, --tasks 256
# SIZE accepts a G/M/K suffix (IEC binary): 8G, 512M, 1024000K.
#
# Memory cap is RSS-enforced on the *aggregate* cgroup (parent + every fork),
# so `perla` spawning gcc/cc1/ld all share one budget. Swap is denied inside
# the cage (MemorySwapMax=0): a runaway gets OOM-killed instead of dragging
# the box into swap-thrash. The system swapfile remains a release valve for
# everything outside the cage (your shell, editor, claude session).
#
# Exit codes:
#   137 = SIGKILL — usually OOM-killed by the cgroup MemoryMax limit, or
#         the SIGKILL phase of RuntimeMaxSec timeout. To disambiguate,
#         compare elapsed time to TIMEOUT, or check `journalctl --user -e`.
#   143 = SIGTERM — RuntimeMaxSec wall-clock timeout (graceful phase).
#   *   = whatever the wrapped command returned.

set -u

TIMEOUT=600
MEM=6G
TASKS=256

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --mem)     MEM="$2";     shift 2 ;;
        --tasks)   TASKS="$2";   shift 2 ;;
        --)        shift; break ;;
        -h|--help)
            sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "safe_run: unknown option: $1" >&2
            echo "usage: $0 [--timeout SEC] [--mem SIZE] [--tasks N] -- CMD [ARGS...]" >&2
            exit 2 ;;
    esac
done

if [[ $# -eq 0 ]]; then
    echo "safe_run: no command given" >&2
    echo "usage: $0 [--timeout SEC] [--mem SIZE] [--tasks N] -- CMD [ARGS...]" >&2
    exit 2
fi

if ! command -v systemd-run >/dev/null 2>&1; then
    echo "safe_run: systemd-run not found; this script requires systemd >= 240" >&2
    exit 2
fi

# Normalize lowercase suffix (systemd wants K/M/G/T uppercase).
MEM_NORM="${MEM^^}"

exec systemd-run \
    --user --scope --quiet --collect \
    -p MemoryMax="$MEM_NORM" \
    -p MemorySwapMax=0 \
    -p TasksMax="$TASKS" \
    -p RuntimeMaxSec="$TIMEOUT" \
    -- "$@"
