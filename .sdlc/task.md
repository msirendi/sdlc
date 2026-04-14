# Feature: SDLC-1 Add `sdlc-status` command for pipeline run visibility

## Summary
Operators currently have no quick way to check the outcome of their last pipeline run without manually browsing `.sdlc/logs/`. Add a `sdlc-status` shell command (and backing script) that prints a concise summary of the most recent pipeline run, including per-step pass/fail results, elapsed time, and log locations.

## Requirements
- Add `orchestrator/status.sh` that reads the most recent run directory under `.sdlc/logs/`, parses the manifest and orchestrator log, and prints a human-readable summary.
- The summary must include: run ID, repository name, each planned step with its outcome (✓ completed / ✗ failed / – skipped), total elapsed time, and the path to the run's log directory.
- If no prior runs exist, print a clear "no runs found" message and exit 0.
- Document the new command in README.md under a new "Checking run status" section.
- Add a `sdlc-status` shell function example to README.md so users know how to wire it into their shell.

## Technical Constraints
- Must be pure Bash (no Python, jq, or other runtime deps beyond coreutils + git).
- Follow the existing coding style in `orchestrator/` (use `sdlc_log`, source `config.sh` and `lib/common.sh`).
- Do not break any existing scripts or shell aliases.
- The script must work when invoked from any directory inside the target repo (resolve repo root via `git rev-parse`).

## Acceptance Criteria
- Running `bash orchestrator/status.sh` inside a repo with at least one prior run prints a correct summary.
- Running it in a repo with no `.sdlc/logs/` prints "No pipeline runs found." and exits 0.
- README.md contains the new section describing `sdlc-status`.
- The script passes `shellcheck` with no errors.

## Files Likely Affected
- orchestrator/status.sh (new)
- README.md (updated)

## Open Questions
- None; scope is intentionally narrow.
