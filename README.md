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

The build sets `umask 002`, so the run directory and its contents are
writable by the allocation group as well as by the user who ran the build.

## Reuse

A run directory is stamped with the sha256 of `ci/build-mpich.sh` and the
MPICH commit. If the stamp matches, the build is skipped and the existing
install is reused as-is, so concurrent pipelines testing the same ref do not
interfere. A branch that moves gets a new stamp and rebuilds in place. A
different ref gets a new directory.

## Variables

| Variable              | Default                                                   | Meaning                                  |
| --------------------- | --------------------------------------------------------- | ---------------------------------------- |
| `MPICH_CI_ROOT`       | `/lus/flare/projects/$MPICH_CI_ALLOCATION/aurora-mpich-ci` | base directory on Aurora                 |
| `MPICH_CI_ALLOCATION` | `Aurora_testing`                                          | allocation in the default root path      |
| `MPICH_REF`           | `aurora_test`                                             | MPICH ref to build (branch, tag, or sha) |
| `MPICH_CI_JOBS`       | `48`                                                      | `make -j` parallelism                    |

## Scripts

- `ci/build-mpich.sh` builds `$MPICH_REF` into its run directory and skips
  the build when the stamp matches.
- `ci/mpich-env.sh` is sourced by the test jobs. It sets up the modules,
  `PATH`, `LD_LIBRARY_PATH`, and the MPICH/libfabric settings for the run's
  install, and checks that `mpicc` resolves to it.
- `ci/run-suite.sh <1node|2node>` runs one bats suite and writes junit
  reports to `reports/`.
- `run_tests.sh <1node|2node>` runs a suite locally with the `mpiexec` and
  `bats` from your `PATH`.
