# Customer settings migration example

This example maps the supplied `cpptestcli.properties` knowledge to isolated settings files for concurrent C++test processes. It does not contain customer credentials or server names.

## What changed

- The settings file is passed with `-settings`; it is never copied into the shared C++test installation.
- The DTP test configuration and GCC 8 compiler selection are settings-file values instead of command-line overrides.
- `dtp.project`, `build.id` and `session.tag` are explicit so parallel DTP publications can be identified correctly.
- Each process receives a separate C++test workspace, report directory and completion marker.
- The original 16 GiB maximum Java heap remains the default, but can be changed with `CPPTEST_MAX_HEAP`.
- Optional mail, source-control, report, encoding, technical-support and Flow Analysis storage knowledge remains available as commented settings.

## Prepare three settings files

Copy the template into a secret-controlled directory that is mounted read-only in the container:

```bash
mkdir -p /run/secrets/cpptest
cp cpptestcli.properties.example /run/secrets/cpptest/project-a.properties
cp cpptestcli.properties.example /run/secrets/cpptest/project-b.properties
cp cpptestcli.properties.example /run/secrets/cpptest/project-c.properties
chmod 600 /run/secrets/cpptest/*.properties
```

Replace every `<PLACEHOLDER>` in each copy. Use distinct project, build and session values where required. An encoded DTP password is still a credential and must not be committed.

The template makes `dtp.enabled=true` explicit because DTP publication is enabled. It requests the same custom license features as the supplied file, but License Server grants only features included in the customer's entitlement.

## Start three isolated processes

Use a different source checkout or worktree for each concurrently running analysis:

```bash
RUN_ROOT=/results ./run-one-analysis.sh project-a /work/project-a /run/secrets/cpptest/project-a.properties &
pid_a=$!
RUN_ROOT=/results ./run-one-analysis.sh project-b /work/project-b /run/secrets/cpptest/project-b.properties &
pid_b=$!
RUN_ROOT=/results ./run-one-analysis.sh project-c /work/project-c /run/secrets/cpptest/project-c.properties &
pid_c=$!

set +e
wait "$pid_a"; result_a=$?
wait "$pid_b"; result_b=$?
wait "$pid_c"; result_c=$?
set -e
```

With `-fail`, C++test may return nonzero when policy violations are found; that is different from an incomplete run. Exit code 137 is treated as an incomplete run and does not create a completion marker.

Before enabling parallel DTP publication in production, verify result separation and license usage with the DTP and License Server administrators.
