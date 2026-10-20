#!/usr/bin/env bats
#
# https://github.com/pmodels/mpich/issues/7971 -- GPU-buffer MPI_Gather fails
# at 128 and 256 bytes on Aurora with 32 nodes, 96 ranks/node (3072 ranks).
# The neighboring sizes passed in the original report. Keep each launch separate
# so an abort or timeout at one size does not hide the other results.

setup_file() {
    cd "${BATS_TEST_DIRNAME}"
    mpicxx -fsycl -std=c++17 sycl_mpi_gather.cpp -o sycl_mpi_gather
}

setup() {
    cd "${BATS_TEST_DIRNAME}"
}

check_gather() {
    run timeout --kill-after=30 300 mpiexec -n 3072 -ppn 96 \
        gpu_tile_compact.sh ./sycl_mpi_gather "$1"
    printf '%s\n' "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MPI_Gather completed successfully"* ]]
}

@test "mpi_issue7971 GPU gather 128 bytes" {
    check_gather 128
}

@test "mpi_issue7971 GPU gather 256 bytes" {
    check_gather 256
}

@test "mpi_issue7971 GPU gather 32 bytes control" {
    check_gather 32
}

@test "mpi_issue7971 GPU gather 64 bytes control" {
    check_gather 64
}

@test "mpi_issue7971 GPU gather 512 bytes control" {
    check_gather 512
}

@test "mpi_issue7971 GPU gather 1024 bytes control" {
    check_gather 1024
}
