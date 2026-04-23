# Feature: SDLC-4 live progress for seeded-output steps

## Summary
Investigate why `sdlc` appears idle during dry-run follow-up and targeted step
executions, especially for `02-technical-spec.md` and `08-open-pr.md`, then
improve the operator feedback so long-running Claude-driven steps show visible
progress and are less likely to be terminated prematurely.

## Requirements
- Determine the actual root cause of the apparent idleness for
  `02-technical-spec.md` and `08-open-pr.md`.
- Make the runner emit clearer in-flight progress signals while a Claude step is
  still working.
- Progress output must explain whether the step's canonical outputs are missing,
  pre-existing but unchanged, or newly updated during the current attempt.
- The operator-facing output must make it clear that Claude stdout is
  final-response-only in the current `--print` execution mode.
- Reduce the silence window enough that long-running steps remain visibly alive
  by default without requiring a second terminal.
- Preserve the existing step summary / artifact validation flow.
- Cover the new behavior with automated tests.

## Technical Constraints
- Preserve the Bash orchestrator architecture and current `claude --print`
  summary-file contract.
- Keep compatibility with macOS and Linux shell tooling.
- Do not treat pre-seeded `.sdlc/artifacts/technical-spec.md` or
  `.sdlc/artifacts/pr-body.md` as proof of progress for the current attempt.
- Continue honoring `HEARTBEAT_INTERVAL=0` as the disable switch.
- Avoid adding noisy output on steps that do not declare tracked canonical
  outputs.

## Acceptance Criteria
- The root cause is documented in code comments, logs, docs, or tests closely
  enough that future maintainers can understand why Steps 02 and 08 looked
  idle.
- When a step with required outputs starts, the orchestrator logs which outputs
  it is tracking and whether they were already present at attempt start.
- During a long-running Step 02 or Step 08 attempt, heartbeat lines report the
  tracked output as `unchanged since attempt start` until the step rewrites it.
- After the tracked file is rewritten during the attempt, a later heartbeat
  reports it as `updated`.
- Default heartbeat cadence is short enough to keep `claude --print` runs
  visibly alive without waiting minutes for the first heartbeat.
- `bash tests/run.sh` passes with new coverage for tracked-output progress.

## Files Likely Affected
- `orchestrator/run-pipeline.sh`
- `orchestrator/lib/execute.sh`
- `orchestrator/lib/common.sh`
- `orchestrator/config.sh`
- `bin/sdlc`
- `README.md`
- `templates/overrides-template.sh`
- `tests/common_unit_test.sh`
- `tests/config_unit_test.sh`
- `tests/sdlc_signals_integration_test.sh`

## Open Questions
- None.
