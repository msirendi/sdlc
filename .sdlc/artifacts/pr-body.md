Fixes #SDLC-1

## Summary
This PR adds an `sdlc-status` command so operators can inspect the latest pipeline run without browsing `.sdlc/logs/` by hand. It delivers the visibility requested in `SDLC-1` by summarizing the most recent run's identity, per-step outcomes, elapsed time, and log location from anywhere inside the target repository.

## Changes
- Orchestration: add `orchestrator/status.sh`, a pure Bash status command that resolves the repo root, reads the newest pipeline run, and renders `completed`, `failed`, and `skipped` step states with elapsed time and log path details.
- Documentation: add a `Checking run status` section to `README.md` with direct usage guidance, status symbol meanings, and a reusable `sdlc-status` shell function example.
- Tests: add Bash unit and integration coverage for manifest parsing, orchestrator-log parsing, nested-directory invocation, no-run handling, malformed latest runs, and the no-repo failure case through `tests/run.sh`.

## How to test
1. Prerequisite: work inside this repository, which already contains sample pipeline runs under `.sdlc/logs/`.
2. From the repo root, run `bash orchestrator/status.sh`.
   Expected: the command prints the latest run ID, repository name, each planned step with `✓`, `✗`, or `–`, elapsed time, and the latest run's log directory.
3. From a nested directory, run `cd orchestrator && bash ./status.sh`.
   Expected: the summary still resolves the repo-root `.sdlc/logs/` directory and prints the same latest-run information.
4. Run `bash tests/run.sh`.
   Expected: the unit and integration suites both pass.
5. Run `shellcheck orchestrator/status.sh tests/testlib.sh tests/status_unit_test.sh tests/status_integration_test.sh tests/run.sh`.
   Expected: `shellcheck` exits cleanly with no findings.

## Risks and considerations
- `orchestrator/status.sh` parses the current manifest and orchestrator log formats, so future logging or manifest format changes need matching parser updates and test coverage.
- The command intentionally inspects the lexically newest run directory and fails fast if that latest run is malformed, which keeps corruption visible but means a bad newest run can mask an older valid run until it is fixed or removed.
