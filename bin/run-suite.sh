#!/usr/bin/env bash
set -euo pipefail

suite=${1:?usage: run-suite.sh <suite-directory>}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$here/bin/mpich-env.sh"

name=$(printf '%s' "${CI_JOB_NAME:-$suite}" | tr -c '[:alnum:]_.-' '_')
export BATS_REPORT_FILENAME="$name.xml"
rm -rf "$here/reports"
mkdir -p "$here/reports"
export OSU_METRICS_FILE="$here/reports/$name.metrics.json"
rc=0
bats --timing --print-output-on-failure -r --report-formatter junit --output "$here/reports" "$here/$suite" || rc=$?
test -s "$here/reports/$BATS_REPORT_FILENAME"
exit "$rc"
