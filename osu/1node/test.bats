#!/usr/bin/env bats
#
# Shared benchmark commands and checks are in ../common.bash.

load ../common

@test "osu binaries preload CI libmpi" {
    osu_check_preload
}

@test "osu pt2pt latency, host buffers" {
    osu_latency host 2
}

@test "osu pt2pt latency, sycl buffers" {
    osu_latency sycl 2
}

@test "osu pt2pt bandwidth, sycl buffers" {
    osu_bandwidth 2
}

@test "osu collective allreduce, sycl buffers" {
    osu_allreduce 4 4
}
