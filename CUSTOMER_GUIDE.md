# Customer Guide: Consolidating Parallel C++test Analysis

## Purpose of the demonstration

This demonstration evaluates whether analyses previously distributed across two Parasoft C/C++test Standard servers can be consolidated onto one C/C++test Professional Automation host.

The test runs three different C projects concurrently:

| Project | Analysis profile | Deliberately seeded issue types |
| --- | --- | --- |
| Flight Sensor Statistics | MISRA C 2023 | Missing braces, essential-type conversions, arithmetic issues |
| Audit Text Processor | Flow Analysis | Uninitialized data, null-pointer path, resource leak |
| Network Command Queue | SEI CERT C | Unsafe string copy, signed overflow, unchecked result |

Each analysis has its own source tree, build directory, C++test workspace, process, configuration and report directory. All three processes share one Automation installation, one container and the same network license service.

## What the public demonstration shows

Open:

https://zuwasi.github.io/cpptest-parallel-automation-demo/

GitHub Pages cannot execute commercial C++test software. The public page is therefore clearly marked **Public Replay**. It reconstructs the observed sequence and results so that the interface and parallel workflow can be reviewed without access to the licensed analysis server.

The repository also includes an inspected screenshot from the real Docker run:

https://zuwasi.github.io/cpptest-parallel-automation-demo/docker-live-proof.png

The real live dashboard runs on the analysis host. It reads actual process output and generated XML reports; it does not use replay data.

### How to read the dashboard

- The header identifies replay or live mode, host platform, toolchain and Docker container ID.
- The three project cards show independent status, PID, elapsed time, license state and scan progress.
- Each console window streams the output of its own C++test process rather than a combined log.
- The requirements area explains why a different rule profile is assigned to each project.
- The result area shows files checked, enabled rules and findings parsed from that project's XML report.
- The summary distinguishes successful process completion from the number of static-analysis findings. Findings are expected because each sample intentionally contains defects.

## Verified result

The reference Docker test used one Ubuntu 24.04 container with C++test Professional 2025.2 and GCC 13.3. The dashboard and all scanner processes ran inside the same container.

The following evidence was independently checked:

- `/.dockerenv` was present inside the dashboard process.
- The dashboard reported the same 12-character container ID as `docker ps`.
- `docker top` showed three C++test Java processes at the same time.
- All three processes independently reported `Automation feature: License is valid`.
- All scanner intervals overlapped for 24 seconds.
- Every process exited with code 0.

| Configuration | Files checked | Rules in report | Findings |
| --- | ---: | ---: | ---: |
| MISRA C 2023 | 3/3 | 385 | 26 |
| Flow Analysis Standard | 3/3 | 105 | 2 |
| SEI CERT C Rules | 3/3 | 192 | 4 |

During the observed parallel interval, Docker reported approximately 1.67 GiB memory, 467 processes/threads and 849% CPU, equivalent to about 8.5 logical CPU cores. These measurements apply only to the small demonstration projects and must not be used as production sizing values.

## Repository contents

Repository:

https://github.com/zuwasi/cpptest-parallel-automation-demo

| Path | Purpose |
| --- | --- |
| `project-alpha/` | MISRA C sample and requirements |
| `project-beta/` | Flow Analysis sample and requirements |
| `project-gamma/` | CERT C sample and requirements |
| `scripts/run-analysis-linux.sh` | Builds and analyzes one project with an isolated workspace |
| `scripts/run-parallel-test-linux.sh` | Starts three Linux scanner processes and verifies overlap |
| `scripts/run-analysis.ps1` | Equivalent single-project Windows runner |
| `scripts/run-parallel-test.ps1` | Equivalent Windows concurrency verifier |
| `server.py` | Live dashboard API, process launcher, console streamer and report parser |
| `docs/` | Browser dashboard and public replay assets |
| `Dockerfile` | Ubuntu runtime containing only open-source prerequisites |
| `compose.yaml` | One-container topology and private volume mounts |
| `Jenkinsfile` | Windows Jenkins parallel-stage example |

The repository does not contain C++test binaries, Parasoft configurations, license credentials, DTP credentials or generated customer reports.

## Reconstructing the Docker demonstration

### 1. Prepare the server

Install the following on a Linux Docker host or a Windows server using Docker Desktop with the Linux container engine:

- Git
- Docker Engine with Docker Compose v2
- A licensed Linux C++test Professional Automation installation
- Network access from containers to the DTP License Server

The tested image uses Ubuntu 24.04, GCC 13 and the C++test `gcc_13-64` compiler profile. Use a compiler/profile pair supported by the customer's installed C++test release.

### 2. Clone the repository

```bash
git clone https://github.com/zuwasi/cpptest-parallel-automation-demo.git
cd cpptest-parallel-automation-demo
```

### 3. Create the private C++test volume

Create the volume expected by `compose.yaml`:

```bash
docker volume create cpptest-linux-2025-2
```

Copy the customer's licensed Linux installation into `/opt/parasoft/cpptest` in that volume. For an installation already stored at `/home/customer/parasoft/cpptest`:

```bash
tar -C /home/customer/parasoft -cf - cpptest \
  | docker run --rm -i \
      -v cpptest-linux-2025-2:/opt/parasoft \
      ubuntu:24.04 tar -C /opt/parasoft -xf -
```

For the reference Windows server, the source installation was in the Ubuntu WSL distribution:

```powershell
docker volume create cpptest-linux-2025-2
cmd /c "wsl.exe tar -C /home/danie/parasoft -cf - cpptest | docker run --rm -i -v cpptest-linux-2025-2:/opt/parasoft ubuntu:24.04 tar -C /opt/parasoft -xf -"
```

The volume may contain license configuration and credentials. Restrict Docker access, do not export the volume and never commit its contents.

### 4. Configure licensing

Configure C++test to use the customer's DTP License Server according to the organization's Parasoft deployment policy. Confirm that:

- The container can resolve and reach the license-server hostname and port.
- The selected edition includes Automation, Static Analysis, Flow Analysis, MISRA and CERT features required by the jobs.
- The purchased license terms permit the intended concurrent use.
- `parasoft.eula.accepted=true` is supplied only after the organization has accepted the applicable EULA.

Do not place passwords or license-server credentials in the repository, Dockerfile or Compose file. Keep them in the private installation volume or an approved secret-management mechanism.

### 5. Build and start the container

```bash
docker compose up -d --build
```

Open the live dashboard on the Docker host:

http://localhost:8876

The header must show `LIVE SERVER`, `C++test Pro 2025.2`, `GCC 13.3 / CMake`, and `Docker` followed by the container ID.

### 6. Run the demonstration

Select **Start parallel scan**. The expected progression is:

1. All three cards enter `running` state.
2. Each card receives a distinct PID.
3. License status changes from `waiting` to `valid`.
4. Three consoles stream different configurations and source files.
5. Every card completes and exposes its generated report.

### 7. Verify Docker independently

Run these commands while the dashboard shows all three analyses as running:

```bash
docker ps --filter name=cpptest-parallel-demo
docker top cpptest-parallel-demo -eo pid,ppid,comm,args
docker stats cpptest-parallel-demo --no-stream
docker inspect cpptest-parallel-demo
```

Acceptance evidence should include:

- One container named `cpptest-parallel-demo`.
- Three command lines containing `org.eclipse.equinox.launcher.Main`.
- Three different `-data` workspace paths.
- Three different `-config` values.
- Three different `-report` paths.
- Dashboard runtime container ID matching `docker ps`.
- Three valid Automation license messages.
- Three successful exit codes and report files.

### 8. Stop or reset the demonstration

Stop the container without deleting reports:

```bash
docker compose stop
```

Remove the demonstration container and network while preserving the two named volumes:

```bash
docker compose down
```

The C++test installation and results volumes are intentionally preserved. Delete them only under the customer's normal data-retention and license-management procedures.

## Running directly on Linux without Docker

If containerization is not required, clone the repository on the Automation host and run:

```bash
export CPPTEST_HOME=/opt/parasoft/cpptest
export CPPTEST_COMPILER_FAMILY=gcc_13-64
export OUTPUT_ROOT=/var/tmp/cpptest-parallel-demo
bash scripts/run-parallel-test-linux.sh
```

The script returns failure unless all three intervals overlap, all Automation licenses validate, every report can be parsed and every scanner exits successfully. The machine-readable result is written to `$OUTPUT_ROOT/parallel-test-result.json`.

## Jenkins integration

The included `Jenkinsfile` demonstrates three parallel Windows branches. For the Docker topology, use a Jenkins agent with Docker access and treat the single container as the Automation execution service:

1. Check out the repository.
2. Run `docker compose up -d --build`.
3. Start analysis with `POST http://localhost:8876/api/run`.
4. Poll `GET http://localhost:8876/api/status` until `running` becomes false.
5. Fail the build unless every project has `status=completed`, `license=valid` and `exitCode=0`.
6. Archive or publish reports from the `cpptest-parallel-results` volume according to the customer's reporting policy.

The reference configuration sets `report.dtp.publish=false` so the proof does not write demonstration results into DTP. Enabling DTP publication should be a separate, controlled integration step using customer project names, build IDs, credentials and retention rules.

## Production migration considerations

The demonstration proves technical concurrency, not production capacity or contractual entitlement. Before replacing the two existing Standard servers:

1. Confirm the Automation license model and concurrency terms with Parasoft or the organization's license administrator.
2. Test representative production codebases, not only the small samples.
3. Measure peak CPU, memory, disk I/O, analysis duration and DTP traffic with two and three concurrent jobs.
4. Establish container CPU and memory limits only after measuring real workloads.
5. Validate compiler profiles, generated-code exclusions, suppressions, baselines and report equivalence.
6. Preserve separate workspaces and report directories for every concurrent job.
7. Define queueing behavior when demand exceeds the safe concurrency level.
8. Add health checks, log retention, backups and monitoring appropriate for the customer environment.
9. Run the old and new systems in parallel during a controlled acceptance period.

The recommended decision criterion is not merely whether three processes can start. Consolidation is ready when representative analyses complete within the required service level, produce equivalent results, remain within licensed concurrency and leave sufficient server capacity for peak demand.
