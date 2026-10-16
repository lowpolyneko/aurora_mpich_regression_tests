#!/usr/bin/env bash
set -euo pipefail

# Run directories are shared with the allocation group.
umask 002

alloc=${MPICH_CI_ALLOCATION:-Aurora_testing}
root=${MPICH_CI_ROOT:-/lus/flare/projects/$alloc/aurora-mpich-ci}
remote=https://github.com/pmodels/mpich.git
ref=${MPICH_REF:-aurora_test}
if [ -n "${CI_PIPELINE_ID:-}" ]; then
    run=mpich-$ref
else
    run=$(whoami)
    rm -rf "${root:?}/${run:?}"
fi

runroot=$root/$run
src=$runroot/src/mpich
prefix=$runroot/mpich
log=$runroot/build.log

section_start() {
    echo -e "\e[0Ksection_start:$(date +%s):$1\r\e[0K${2:-${1%[\[]*}}"
}

section_end() {
    echo -e "\e[0Ksection_end:$(date +%s):${1%[\[]*}\r\e[0K"
}

stage() {
    local name rc=0
    name=$(echo "$*" | tr -cs '[:alnum:]' '_')
    section_start "${name}[collapsed=true]"
    "$@" 2>&1 | tee -a "$log" || rc=$?
    section_end "${name}[collapsed=true]"
    [ "$rc" = 0 ] || exit 1
}

resolve_ref() {
    local sha
    if [[ $1 =~ ^[0-9a-f]{40}$ ]]; then
        printf '%s\n' "$1"
        return
    fi
    sha=$(git ls-remote "$remote" "refs/heads/$1" | awk '{print $1; exit}')
    if [ -z "$sha" ]; then
        # For tags prefer the peeled (commit) sha of an annotated tag.
        sha=$(git ls-remote "$remote" "refs/tags/$1" "refs/tags/$1^{}" \
            | awk 'END {print $1}')
    fi
    if [ -z "$sha" ]; then
        echo "cannot resolve $1 on $remote" >&2
        return 1
    fi
    printf '%s\n' "$sha"
}

module reset
module unload mpich
module load autoconf/2.72 automake/1.16.5 hwloc/2.12.2

hwloc=$(dirname "$(dirname "$(command -v hwloc-info)")")

mkdir -p "$runroot"

curl -fsS --max-time 15 -o /dev/null https://github.com/ \
    || export http_proxy=http://proxy.alcf.anl.gov:3128 https_proxy=http://proxy.alcf.anl.gov:3128

sha=$(resolve_ref "$ref")
stamp="$(sha256sum "$0" | cut -d' ' -f1) $sha"

if [ "$(cat "$prefix/.stamp" 2>/dev/null)" = "$stamp" ]; then
    echo "==> reusing $prefix at $sha"
    exit 0
fi

# Leftovers of an earlier attempt at this run (job retry).
rm -rf "$prefix" "$runroot/bats-core" "$log"
touch "$log"

stage git clone --depth 1 -b v1.11.0 \
    https://github.com/bats-core/bats-core.git "$runroot/bats-core"

if [ ! -d "$src/.git" ]; then
    rm -rf "$src"
    mkdir -p "$src"
    git -C "$src" init -q
    git -C "$src" remote add origin "$remote"
fi

stage git -C "$src" fetch --depth 1 origin "$ref"
stage git -C "$src" checkout --detach FETCH_HEAD
sha=$(git -C "$src" rev-parse HEAD)
stamp="$(sha256sum "$0" | cut -d' ' -f1) $sha"

stage git -C "$src" submodule update --init --recursive --depth 1

cd "$src"
stage ./autogen.sh
stage ./configure --prefix="$prefix" \
    --disable-maintainer-mode --disable-silent-rules \
    --enable-shared --enable-static \
    --with-pm=no --enable-romio --without-ibverbs --enable-wrapper-rpath=yes \
    --with-yaksa=embedded --with-ze --with-ch4-shmmods=posix,gpudirect \
    --with-hwloc="$hwloc" \
    --enable-fortran --with-slurm=no --with-pmi=pmix --with-pmix=/usr \
    --without-cuda --without-hip \
    --with-device=ch4:ofi --with-libfabric=/opt/cray/libfabric/2.3.1 \
    --enable-libxml2 --with-datatype-engine=yaksa --with-xpmem=/usr \
    --with-file-system=daos+lustre+nfs+ufs --with-daos=/usr \
    --enable-timer-type=linux86_cycle \
    --enable-fast=O3,alwaysinline,avx,avx2,avx512f,sse2 \
    --enable-g=no --disable-debuginfo --enable-error-checking=runtime \
    --without-valgrind --enable-ch4-mt=runtime \
    --with-ze=/usr --enable-ze-native=pvc --disable-opencl \
    CC=icx CXX=icpx FC=ifx F77=ifx
stage make -j"${MPICH_CI_JOBS:-48}"
stage make install

grep -q 'device *: ch4:ofi' "$log"
grep -q 'gpu support *: ZE' "$log"
printf '%s\n' "$stamp" >"$prefix/.stamp"

echo "==> built $prefix at $sha"
