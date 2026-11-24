#!/usr/bin/env bash
#
# Run an OSU benchmark from Aurora's software stack with the MPICH selected
# by mpicc. The stock binaries' DT_RPATH selects a system MPICH ahead of
# LD_LIBRARY_PATH.
#
# Usage:
#   run-osu.sh [--check] pt2pt/osu_latency [benchmark args]
#
# --check prints the benchmark's library resolution under the same preload
# and fails if it does not use our libmpi. OSU_MB_HOME and MPICH_CI_LIBMPI
# can override the discovered OSU directory and libmpi, respectively.

set -euo pipefail
shopt -s nullglob

check=false
if [ "${1:-}" = "--check" ]; then
    check=true
    shift
fi
if [ "$#" = 0 ]; then
    echo "usage: $0 [--check] <benchmark> [args...]" >&2
    exit 2
fi
benchmark=$1
shift

mpicc=$(command -v mpicc || true)
[ -n "$mpicc" ] || { echo "mpicc is not on PATH" >&2; exit 1; }
libdir=$(cd "$(dirname "$mpicc")/../lib" && pwd -P)
libmpi=${MPICH_CI_LIBMPI:-$libdir/libmpi.so.12}
[ -f "$libmpi" ] || { echo "no libmpi at $libmpi" >&2; exit 1; }

osu_home=${OSU_MB_HOME:-}
if [ -z "$osu_home" ]; then
    installs=(/opt/aurora/default/spack/unified/*/install/linux-x86_64/osu-micro-benchmarks-7.5.2-*)
    stack=${installs[0]:-}
    osu_home=${stack:+$stack/libexec/osu-micro-benchmarks/mpi}
fi
[ -n "$osu_home" ] || { echo "no OSU 7.5.2 installation found" >&2; exit 1; }
binary=$osu_home/$benchmark
[ -x "$binary" ] || { echo "no executable benchmark at $binary" >&2; exit 1; }

dynamic_section=$(readelf -d "$binary")
grep -Fq 'Shared library: [libmpi.so.12]' <<<"$dynamic_section" || {
    echo "$binary does not use the libmpi.so.12 ABI" >&2
    exit 1
}

export LD_PRELOAD="$libmpi${LD_PRELOAD:+:$LD_PRELOAD}"

if [ "$check" = true ]; then
    resolution=$(ldd "$binary")
    printf '%s\n' "$resolution"
    grep -Fq "$libmpi" <<<"$resolution" || {
        echo "$libmpi was not preloaded" >&2
        exit 1
    }
    if grep 'libmpi\.so.*=>' <<<"$resolution"; then
        echo "$benchmark also resolved libmpi through its RPATH" >&2
        exit 1
    fi
    exit 0
fi

exec "$binary" "$@"
