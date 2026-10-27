setup() {
    cd "${BATS_TEST_DIRNAME}"
}

osu_check_preload() {
    local bench
    for bench in pt2pt/osu_latency pt2pt/osu_bw collective/osu_allreduce; do
        "${BATS_TEST_DIRNAME}/../../bin/run-osu.sh" --check "$bench" || return
    done
}

# Bats sets status and output via run.
# shellcheck disable=SC2154
_osu_check_result() {
    local header=$1 largest_size=$2 line
    while IFS= read -r line; do
        printf '# %s\n' "$line" >&3
    done <<<"$output"
    [ "$status" -eq 0 ] || return
    grep -q "$header" <<<"$output" || return
    grep -Eq "^${largest_size}[[:space:]]+[0-9]" <<<"$output"
}

_osu_record_metrics() {
    local output_file=${OSU_METRICS_FILE:-$BATS_TEST_TMPDIR/metrics.json}
    python3 "${BATS_TEST_DIRNAME}/../parse_metrics.py" \
        --suite "$(basename "$BATS_TEST_DIRNAME")" \
        --benchmark "$1" --buffers "$2" --ranks "$3" --ppn "$4" \
        --output "$output_file" <<<"$output"
}

# osu_latency <host|sycl> <ppn>
osu_latency() {
    local -a launcher=() args=(-z)
    local header="# OSU MPI Latency Test"
    if [ "$1" = sycl ]; then
        launcher=(gpu_tile_compact.sh)
        args+=(-d sycl)
        header="# OSU MPI-SYCL Latency Test"
    fi
    run timeout 300 mpiexec -n 2 --ppn "$2" \
        "${launcher[@]}" "${BATS_TEST_DIRNAME}/../../bin/run-osu.sh" \
        pt2pt/osu_latency "${args[@]}" -m 8:2^20 -i 200 -x 20
    _osu_check_result "$header" 1048576
    _osu_record_metrics pt2pt/osu_latency "$1" 2 "$2"
}

# osu_bandwidth <ppn>
osu_bandwidth() {
    run timeout 300 mpiexec -n 2 --ppn "$1" gpu_tile_compact.sh \
        "${BATS_TEST_DIRNAME}/../../bin/run-osu.sh" pt2pt/osu_bw -d sycl \
        -m 2^16:2^22 -i 50 -x 10
    _osu_check_result "# OSU MPI-SYCL Bandwidth Test" 4194304
    _osu_record_metrics pt2pt/osu_bw sycl 2 "$1"
}

# osu_allreduce <ranks> <ppn>
osu_allreduce() {
    run timeout 300 mpiexec -n "$1" --ppn "$2" gpu_tile_compact.sh \
        "${BATS_TEST_DIRNAME}/../../bin/run-osu.sh" collective/osu_allreduce \
        -d sycl -f -z -m 8:2^16 -i 100 -x 10
    _osu_check_result "# OSU MPI-SYCL Allreduce Latency Test" 65536
    _osu_record_metrics collective/osu_allreduce sycl "$1" "$2"
}
