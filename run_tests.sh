#!/usr/bin/env bash
#
# Run a bats suite in one directory.
#
#   ./run_tests.sh 1node
#   ./run_tests.sh 2node
#   ./run_tests.sh 32node
#   ./run_tests.sh osu/2node
#
# Needs mpiexec, bats, and (for the osu tests) mpicc on PATH.
# To get bats:
#   git clone --depth 1 -b v1.11.0 https://github.com/bats-core/bats-core.git
#   export PATH=$PWD/bats-core/bin:$PATH

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
directory=${1:-}
shift || true

if [ ! -d "${here}/${directory}" ]; then
    echo "usage: $0 <directory>" >&2
    exit 2
fi

exec bats --timing --print-output-on-failure -r "$@" "${here}/${directory}"
