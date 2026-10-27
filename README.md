# aurora_mpich_regression_tests

The pipeline in [`.gitlab-ci.yml`](.gitlab-ci.yml) builds MPICH on Aurora and
runs the bats suites in [`1node/`](1node/) and [`2node/`](2node/) against it.

## Layout on Aurora

Run directories are under `$MPICH_CI_ROOT`
(`/lus/flare/projects/$MPICH_CI_ALLOCATION/aurora-mpich-ci` by default):

    $MPICH_CI_ROOT/
    └── mpich-<ref>/       one directory per MPICH ref
        ├── mpich/         install prefix, used by the test jobs
        ├── bats-core/     test framework (v1.11.0)
        ├── src/mpich/     source and build tree
        └── build.log

`<ref>` is `$MPICH_REF` (`aurora_test` by default). Manual runs use the user
name instead and wipe that directory before building. Old run directories are
not removed automatically.

MPICH builds and CI test jobs set `umask 002`, so the run directory and
generated test artifacts are writable by the allocation group as well as by
the user.

## Reuse

A run directory is stamped with the sha256 of `bin/build-mpich.sh` and the
MPICH commit. If the stamp matches, the build is skipped and the existing
install is reused as-is, so concurrent pipelines testing the same ref do not
interfere. A branch that moves gets a new stamp and rebuilds in place. A
different ref gets a new directory.

## Variables

| Variable              | Default                                                   | Meaning                                  |
| --------------------- | --------------------------------------------------------- | ---------------------------------------- |
| `MPICH_CI_ROOT`       | `/lus/flare/projects/$MPICH_CI_ALLOCATION/aurora-mpich-ci` | base directory (tegu on Sunspot)         |
| `MPICH_CI_ALLOCATION` | `Aurora_testing`                                          | allocation in the default root path      |
| `MPICH_REF`           | `aurora_test`                                             | MPICH ref to build (branch, tag, or sha) |
| `MPICH_CI_JOBS`       | `48`                                                      | `make -j` parallelism                    |

## Scripts

- `bin/build-mpich.sh` builds `$MPICH_REF` into its run directory and skips
  the build when the stamp matches.
- `bin/run-osu.sh` locates the SYCL-enabled OSU 7.5.2
  binaries in Aurora's software stack and runs them with the MPICH selected
  by `mpicc`. Its `LD_PRELOAD` overrides the binaries' RPATH to a system
  MPICH.
  The OSU suite has no node selections by default. Set `osu_nodes` to choose
  which benchmark jobs to run.
- `osu/parse_metrics.py` writes benchmark results with explicit units to
  `.metrics.json` files. CI jobs expose them under **OSU metrics**.
- `bin/mpich-env.sh` is sourced by the test jobs. It sets up the modules,
  `PATH`, `LD_LIBRARY_PATH`, and the MPICH/libfabric settings for the run's
  install, and checks that `mpicc` resolves to it.
- `bin/run-suite.sh <suite-directory>` runs one bats suite and writes junit
  reports, including full OSU benchmark output, to `reports/`.
- `run_tests.sh <suite-directory>` runs a suite locally with the `mpiexec` and
  `bats` from your `PATH`.
