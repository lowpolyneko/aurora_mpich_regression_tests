#!/usr/bin/env bats
#
# Shared benchmark commands and checks are in ../common.bash.

load ../common

@test "osu binaries preload CI libmpi" {
    osu_check_preload
}

@test "osu inter-node pt2pt latency, host buffers" {
    osu_latency host 1
}

@test "osu inter-node pt2pt latency, sycl buffers" {
    osu_latency sycl 1
}

@test "osu inter-node pt2pt bandwidth, sycl buffers" {
    osu_bandwidth 1
}

@test "osu inter-node collective allreduce, sycl buffers" {
    osu_allreduce 4 2
}
