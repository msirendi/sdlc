# Technical Spec: SDLC-1 Add `sdlc-status` command for pipeline run visibility

## Summary
Implement a new read-only Bash entrypoint, `orchestrator/status.sh`, that locates the newest pipeline run under `.sdlc/logs/`, parses the existing `pipeline-manifest.md` and `orchestrator.log` artifacts written by `orchestrator/run-pipeline.sh`, and prints a concise operator-facing summary from any directory inside the governed repository. The output must include the run ID, repository name, each planned step's terminal outcome, total elapsed time, and the absolute path to the run log directory without adding new runtime dependencies or changing current pipeline behavior.

## Scope boundary

### In scope
- Add `orchestrator/status.sh` as a pure Bash script that resolves the target repository root with `git rev-parse`, sources `orchestrator/config.sh` and `orchestrator/lib/common.sh`, and reads the latest run data from `.sdlc/logs/`.
- Parse the ordered list of planned steps from `pipeline-manifest.md` so the summary reflects the actual run plan after filters such as `--start-from`, `--only`, and manual-step exclusion.
- Parse `orchestrator.log` for repository name, completed step markers, the halted step marker, and the final elapsed-time line.
- Map every planned step to one of the required terminal states: `✓ completed`, `✗ failed`, or `– skipped`.
- Return a clear `No pipeline runs found.` message with exit code `0` when the repository has no prior run directories.
- Document the command in `README.md` under a new `Checking run status` section, including a shell function example for `sdlc-status`.
- Verify the new script with `shellcheck` and shell-level scenarios that cover no-run, success, failure, and subdirectory invocation behavior.

### Out of scope
- Changing `orchestrator/run-pipeline.sh`, the manifest format, or the orchestrator log format. The existing run artifacts already contain the data required for this feature, and touching the runner adds avoidable regression risk.
- Surfacing historical runs other than the newest run, adding filters, or building an interactive status UI. The ticket is specifically about the most recent run.
- Streaming live progress or tailing logs for an active run. This command is a snapshot over persisted run artifacts.
- Refactoring shared parsing helpers into `orchestrator/lib/`. The feature is small, and keeping the parsing logic local to `status.sh` avoids unnecessary interaction with existing library code.

## Design decisions

### Decision 1: Select the latest run by lexically sorting run directory names
- Choice: Read child directories beneath `.sdlc/logs/`, filter to directories, sort them lexically, and use the final entry as the latest run.
- Alternatives considered: `ls -t`, filesystem mtimes, or persisting a separate `latest` pointer file.
- Why this wins: `run-pipeline.sh` already names run directories with sortable timestamps such as `20260413-142531`, so lexical sorting is deterministic and portable in pure Bash. Mtime-based selection is less stable after copies or restores, and a pointer file would introduce additional state to maintain.

### Decision 2: Use `pipeline-manifest.md` as the source of planned steps and `orchestrator.log` as the source of outcomes
- Choice: Parse the planned step list from the manifest, then overlay terminal outcomes from the orchestrator log.
- Alternatives considered: deriving steps from the repository's step markdown files, parsing attempt logs, or inspecting step summary files.
- Why this wins: the manifest records the exact step set for that run after operator-selected filters, while the orchestrator log records the final success or halt markers after retries. Using repo step files would misreport runs started with `--start-from` or `--only`.

### Decision 3: Keep the status implementation self-contained in `orchestrator/status.sh`
- Choice: Reuse `config.sh` and `lib/common.sh` for SDLC conventions and logging, but keep parsing helpers private to the new script.
- Alternatives considered: adding new generic helpers to `orchestrator/lib/common.sh`.
- Why this wins: the new command is read-only and narrow in scope, so a local implementation is simpler and safer. It also minimizes interference with unrelated library changes already present in the working tree.

### Decision 4: Derive the three required step states from final orchestrator markers
- Choice: Mark a step as `✓ completed` when the log contains `Completed <step>`, mark it as `✗ failed` when the log contains `Pipeline halted at <step>`, and mark all other planned steps as `– skipped`.
- Alternatives considered: introducing an explicit `running` or `unknown` state, or parsing attempt-level warnings and non-terminal failures.
- Why this wins: the ticket requires exactly three output states. The terminal `Completed ...` and `Pipeline halted at ...` lines already reflect the final post-retry outcome. Steps without either marker were part of the plan but did not finish successfully in that persisted run.

### Decision 5: Prefer the logged elapsed-seconds summary and degrade gracefully when it is missing
- Choice: Read elapsed time from the final `Run complete: ... <N>s elapsed.` line in `orchestrator.log`. If that line is absent, print an explicit `Elapsed: unavailable` message and note that the latest run may still be in progress or interrupted.
- Alternatives considered: subtracting log timestamps with `date`, using directory mtimes, or summing attempt durations.
- Why this wins: the runner already emits authoritative elapsed seconds, which avoids non-portable date arithmetic on macOS. A graceful fallback keeps the script dependency-free and still useful when the newest run directory is only partially written.

### Decision 6: Report the repository name from the run artifacts, not from the caller's current directory
- Choice: Parse the repository name from `[INFO] Repository: ...` in `orchestrator.log`, with a fallback to the basename of the manifest's `Repository:` path if needed.
- Alternatives considered: always using `basename "$(git rev-parse --show-toplevel)"`.
- Why this wins: the summary should reflect the recorded run, even when the caller invokes the command from a nested path. The current repo root is still used to locate `.sdlc/logs/`, but the displayed name comes from the run artifacts themselves.

## Change plan

1. `orchestrator/status.sh`
   Add a new executable Bash script that mirrors the bootstrap pattern in the existing orchestrator entrypoints: `set -euo pipefail`, compute `SDLC_HOME`, source `config.sh` and `lib/common.sh`, require `git`, and resolve the repository root with `git rev-parse --show-toplevel`. The script should remain read-only and should not modify any `.sdlc` contents.

2. `orchestrator/status.sh`
   Implement latest-run discovery by reading `$REPO_ROOT/$LOGS_DIR_REL`, selecting the lexically newest run directory, and validating that both `pipeline-manifest.md` and `orchestrator.log` exist inside it. If the log directory is missing or has no run subdirectories, print `No pipeline runs found.` and exit `0`. If a run directory exists but required files are missing, fail clearly with a non-zero exit because the artifacts are malformed rather than absent.

3. `orchestrator/status.sh`
   Parse `pipeline-manifest.md` into an ordered array of planned steps by reading the `## Planned steps` section and extracting only the step filenames. This keeps the output aligned with the actual execution plan and intentionally excludes the separately listed manual steps skipped by default.

4. `orchestrator/status.sh`
   Parse `orchestrator.log` to collect:
   - `Repository: <name>` for display.
   - Every `Completed <step>` marker into a completed-step lookup.
   - The single `Pipeline halted at <step>` marker, if present, as the failed step.
   - The final `Run complete: ... <seconds>s elapsed.` value for elapsed time.
   The parser should ignore per-attempt warnings and retries so the displayed status reflects only the terminal state of each step.

5. `orchestrator/status.sh`
   Render a human-readable summary that includes:
   - Run ID, taken from the latest run directory name.
   - Repository name.
   - One line per planned step with `✓ completed`, `✗ failed`, or `– skipped`.
   - Total elapsed time from the logged elapsed seconds, or `unavailable` if the run has no final completion line yet.
   - The absolute path to the run log directory.
   If the newest run has no completion line, append a short note that the run may still be in progress or interrupted so operators understand why elapsed time is unavailable and later steps remain skipped.

6. `README.md`
   Add a new `Checking run status` section near the existing usage docs. Document the direct invocation (`bash "$SDLC_HOME/orchestrator/status.sh"`), describe the meaning of the three status symbols, and add a `sdlc-status` shell function example that parallels the existing `sdlc`, `sdlc-dry`, and `sdlc-init` workflow described elsewhere in the README.

7. No changes to the runner or shared libraries
   Leave `orchestrator/run-pipeline.sh`, `orchestrator/lib/common.sh`, and other shared scripts untouched unless implementation exposes a hard blocker. This keeps the feature isolated and avoids regressions in the main execution path.

## Edge cases and failure modes
- Edge case: `.sdlc/logs/` does not exist or contains no run directories.
  Handling: print `No pipeline runs found.` and exit `0`.
- Edge case: the latest run directory exists but is missing `pipeline-manifest.md` or `orchestrator.log`.
  Handling: print a clear error via `sdlc_log` and exit non-zero because the latest run artifacts are incomplete or corrupted.
- Edge case: the latest run is still being written and does not yet contain a final `Run complete:` line.
  Handling: show any already completed steps, leave the remaining planned steps as `– skipped`, print `Elapsed: unavailable`, and note that the run may still be in progress or interrupted.
- Edge case: a step failed on an early attempt and later succeeded after retry.
  Handling: treat the step as `✓ completed` because only terminal `Completed ...` and `Pipeline halted ...` markers are authoritative.
- Edge case: the run was started with `--start-from`, `--only`, or default manual-step exclusion.
  Handling: only display the steps recorded under the manifest's `## Planned steps` section; do not infer omitted steps from the repository.
- Edge case: the command is invoked from a nested directory inside the repository.
  Handling: resolve the repository root with `git rev-parse --show-toplevel` before locating `.sdlc/logs/`.
- Failure mode: the command is invoked outside a git repository.
  Expected behavior: print a clear error and exit non-zero.
- Failure mode: `git` is unavailable in the operator environment.
  Expected behavior: fail early through `sdlc_require_command "git"` with an installation hint.
- Failure mode: log parsing finds no repository name even though the run directory is otherwise valid.
  Expected behavior: fall back to the basename of the manifest `Repository:` path, then finally the current repo root basename if needed.

## Test strategy
- Unit coverage:
  Verify the parser helpers with fixture-backed shell scenarios that cover latest-run selection, manifest step extraction, completed-step detection, failed-step detection, and the default skipped-state mapping.
- Integration coverage:
  Execute `bash orchestrator/status.sh` inside temporary git repositories that contain fixture `.sdlc/logs/` data for:
  - No runs present.
  - A successful run where every planned step completed.
  - A failed run where one step halts the pipeline and later steps must render as skipped.
  - Invocation from a subdirectory inside the repo.
  - A partially written latest run with no final elapsed line.
- Fixtures, mocks, or seed data:
  Use synthetic `pipeline-manifest.md` and `orchestrator.log` files modeled on the current `run-pipeline.sh` output format. Avoid mocking the parser logic itself; instead, build small on-disk fixture directories that the script reads exactly as it would in production.
- Static analysis:
  Run `shellcheck orchestrator/status.sh` and treat any warning as a blocker for merge.

## Acceptance criteria traceability

| Acceptance criterion | Planned change | Planned test |
| --- | --- | --- |
| Running `bash orchestrator/status.sh` inside a repo with at least one prior run prints a correct summary. | Change plan items 1-5 implement latest-run discovery, artifact parsing, outcome mapping, and summary rendering. | Integration fixtures for successful and failed runs validate run ID, repo name, per-step statuses, elapsed time, and log path output. |
| Running it in a repo with no `.sdlc/logs/` prints `No pipeline runs found.` and exits `0`. | Change plan item 2 adds explicit no-run detection and zero-exit behavior. | No-run integration scenario verifies the exact message and exit code `0`. |
| `README.md` contains the new section describing `sdlc-status`. | Change plan item 6 adds `Checking run status` documentation and shell function example. | Documentation review in the implementation step confirms the section exists and includes both direct invocation and shell wiring guidance. |
| The script passes `shellcheck` with no errors. | Change plan item 1 keeps the script simple and idiomatic Bash; test strategy includes static analysis. | Run `shellcheck orchestrator/status.sh` and require exit code `0`. |

## Open questions
- None for feature scope.
- Source note: the connected Linear workspace did not resolve `SDLC-1` during this step, so `.sdlc/task.md` was treated as the canonical ticket copy for this spec.
