#!/usr/bin/env python3
"""Turn one OMB result table into a structured CI metrics document."""

import argparse
import json
import os
import re
import sys
from pathlib import Path

FIELDS = {
    "Avg Latency(us)": "average_latency_us",
    "Min Latency(us)": "min_latency_us",
    "Max Latency(us)": "max_latency_us",
    "Bandwidth (MB/s)": "bandwidth_mb_per_s",
    "Avg Bandwidth (MB/s)": "bandwidth_mb_per_s",
    "Iterations": "iterations",
}


def parse_output(text):
    header = re.search(r"^# (Size .+)$", text, re.MULTILINE)
    if not header:
        raise ValueError("no OMB result table found")

    columns = re.split(r"\s{2,}", header.group(1))
    keys = ["message_size_bytes"]
    for column in columns[1:]:
        tail = re.fullmatch(r"P(\d+) Tail Lat\(us\)", column)
        if tail:
            keys.append(f"tail_latency_us.P{tail.group(1)}")
        elif column in FIELDS:
            keys.append(FIELDS[column])
        else:
            raise ValueError(f"unsupported OMB column: {column}")

    samples = []
    for line in text[header.end() :].splitlines():
        values = line.split()
        if not values or not values[0].isdigit():
            continue
        if len(values) != len(keys):
            raise ValueError(f"result row does not match its header: {line}")

        sample = {}
        for index, key in enumerate(keys):
            parent, _, child = key.partition(".")
            value = int(values[index]) if key in ("message_size_bytes", "iterations") else float(values[index])
            if child:
                sample.setdefault(parent, {})[child] = value
            else:
                sample[key] = value
        samples.append(sample)

    if not samples:
        raise ValueError("OMB result table has no samples")

    version = re.search(r"^# OSU .* v([\w.-]+)$", text, re.MULTILINE)
    datatype = re.search(r"^# Datatype: (\w+)", text, re.MULTILINE)
    return {
        "osu_version": version.group(1) if version else None,
        "datatype": datatype.group(1) if datatype else None,
        "samples": samples,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", required=True)
    parser.add_argument("--benchmark", required=True)
    parser.add_argument("--buffers", required=True)
    parser.add_argument("--ranks", required=True, type=int)
    parser.add_argument("--ppn", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    result = parse_output(sys.stdin.read())
    record = {
        "suite": args.suite,
        "benchmark": args.benchmark,
        "buffers": args.buffers,
        "ranks": args.ranks,
        "ppn": args.ppn,
        **result,
    }
    key = tuple(record[name] for name in ("suite", "benchmark", "buffers", "ranks", "ppn"))

    if args.output.exists():
        document = json.loads(args.output.read_text())
        if document.get("schema_version") != 1:
            raise ValueError("unsupported metrics schema version")
    else:
        document = {"schema_version": 1, "benchmarks": []}

    records = {}
    for previous in document["benchmarks"]:
        records[tuple(previous[name] for name in ("suite", "benchmark", "buffers", "ranks", "ppn"))] = previous
    records[key] = record

    for name, variable in (("mpich_ref", "MPICH_REF"), ("commit_sha", "CI_COMMIT_SHA")):
        if os.environ.get(variable):
            document[name] = os.environ[variable]
    document["benchmarks"] = list(records.values())
    args.output.write_text(json.dumps(document, indent=2, allow_nan=False) + "\n")


if __name__ == "__main__":
    main()
