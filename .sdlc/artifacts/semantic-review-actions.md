# Step 11 — Semantic Review Actions: SDLC-3

Source: `.sdlc/reports/semantic_diff_report_SDLC-3.html`

Each entry below lists one edit tagged `Weakly justified` or
`Unclear / possibly superfluous` (or flagged in the footer's "Missing or weak
test coverage" / "Changes needing author explanation" lists), the action taken
against it, and a one-sentence rationale. The guardrail is the step's: weak
edits are strengthened, unclear edits are justified inline, and superfluous
edits are removed.

## Weakly justified / weakly covered edits

### 1. `orchestrator/lib/execute.sh` + `orchestrator/run-pipeline.sh` — SIGINT contract had no automated test (Block 2)

- Location: `orchestrator/run-pipeline.sh:32-69` (`signal_process_tree`,
  `terminate_current_step`, `handle_interrupt`), `orchestrator/lib/execute.sh:96-129`
  (backgrounded subshell + `wait`).
- Label: `Weakly covered by tests` (Block 2).
- **Action — Fix (added test).** Wrote
  `tests/sdlc_signals_integration_test.sh::test_sdlc_terminate_signal_exits_130_and_kills_claude_descendants`,
  which drives the real `sdlc` wrapper against a claude shim that `exec`s
  `sleep 47`, sends an interrupt, and asserts exit-130 plus no orphan
  descendant pid. Rationale: the most load-bearing code in the branch now
  has end-to-end regression coverage proving the backgrounded-subshell +
  pgrep-tree machinery actually terminates its descendants.
- The test uses SIGTERM instead of SIGINT because a non-interactive bash
  parent installs `SIG_IGN` on SIGINT for its `&`-backgrounded children and
  macOS lacks `setsid`; the orchestrator traps both signals through the
  identical `handle_interrupt`, so SIGTERM exercises the same trap path.
  The rationale is documented in-test.

### 2. `orchestrator/run-pipeline.sh` — heartbeat loop only covered by config-default test (Block 3)

- Location: `orchestrator/run-pipeline.sh:73-90` (`emit_heartbeat_loop`,
  `stop_heartbeat`) and the integration inside `execute_step_with_retries`.
- Label: `Weakly covered by tests` (Block 3).
- **Action — Fix (added tests).** Added
  `test_heartbeat_loop_emits_still_running_line_during_step` (runs sdlc with
  `HEARTBEAT_INTERVAL=1` against a 3-second shim and asserts the
  `still running (elapsed: Ns)` log format) and
  `test_heartbeat_interval_zero_suppresses_heartbeat_lines` (proves the
  `HEARTBEAT_INTERVAL=0` disable path). Rationale: regressions in the
  `sleep & wait` pattern, the log format, or the `[[ -gt 0 ]]` guard will
  now break a test rather than silently ship.

## Unclear / possibly superfluous edits

### 3. `.sdlc/task.md`, `.sdlc/artifacts/test-results.md` — pipeline bookkeeping on a product PR (Block 6)

- Label: `Reviewer question / Unclear` (Block 6's footer note and the PR-level
  "Potentially superfluous changes" section).
- **Action — Justify (kept as-is; rationale recorded here).** These files
  are canonical pipeline inputs/outputs defined in `orchestrator/config.sh`:
  `.sdlc/task.md` is the feature-intent document Steps 01–02 read, and
  `.sdlc/artifacts/test-results.md` is the Step 6 output declared in
  `STEP_REQUIRED_PATTERNS` and consumed by the 06↔07 test-fix loop. When
  the SDLC tooling is developed against its own repository (as here),
  these files must be rewritten per feature — otherwise the previous
  feature's content poisons Step 02's spec input and the Step 6 validator
  rejects the stale results. Deleting them is not an option; they are
  load-bearing. Leaving them on the PR is the least-bad alternative, and
  the reviewer note in the semantic diff surfaces the hygiene discussion
  for a future process change (e.g. rotating `.sdlc/task.md` snapshots out
  of the product PR scope).

## Footer items — "Changes that need author explanation"

### 4. `orchestrator/run-pipeline.sh` — 2s TERM→KILL window was unexplained

- Location: `terminate_current_step`'s `waited < 20` poll loop.
- **Action — Justify (added inline comment).** The window has two competing
  requirements: it must be long enough for Claude's tee pipeline to flush
  trailing bytes into the summary file (so the operator does not lose
  partial output on Ctrl+C), and short enough that a wedged child does not
  stall the exit perceptibly. The new comment above the poll loop captures
  both constraints.

### 5. `orchestrator/run-pipeline.sh` `emit_step_summary_excerpt` — `5. Status:` regex coupling was implicit

- Location: `emit_step_summary_excerpt`'s `grep -E '^[[:space:]]*(5\.[[:space:]]*)?Status:'`.
- **Action — Justify (tightened comment).** The `5.` prefix matches the
  numbered "Final Response Format" template that `execute.sh`'s prompt
  hands to Claude (`5. Status: READY or BLOCKED`). `validate.sh`'s status
  parser uses the same two-form alternation. The updated comment above
  `emit_step_summary_excerpt` documents the contract linkage and names
  both sites that must move together if the template is ever renumbered.

### 6. `orchestrator/config.sh` — `HEARTBEAT_INTERVAL=""` would crash the `[[ -gt 0 ]]` guard

- Location: `orchestrator/config.sh:29` → `run-pipeline.sh` heartbeat spawn check.
- **Action — Fix (added validation).** Added a regex check at the point of
  load: if the override is not a non-negative integer, clamp back to the
  default `120`. This closes the latent crash path under
  `set -euo pipefail` where an empty or non-numeric `HEARTBEAT_INTERVAL` in
  `overrides.sh` would error out the pipeline. Rationale is documented in
  the config comment above the clamp.

## Footer items — "Missing or weak test coverage"

### 7. `tests/bin_wrappers_unit_test.sh` — help test asserted four of the five AC sections

- Location: `test_sdlc_help_prints_user_facing_overview`.
- **Action — Fix (added assertion).** Added
  `assert_contains "$output" "PIPELINE STEPS"` so the help test now pins
  all five AC-named sections (`USAGE`, `TYPICAL FLOW`, `PIPELINE STEPS`,
  `DURING A RUN` via `Press Ctrl+C`, `sdlc-status` cross-reference).

### 8. No test for the Status excerpt emission

- **Action — Accept (no fix).** The semantic report itself labels the
  excerpt as "informational, not contractual." The regex's `5.` coupling
  is now covered by the tightened comment at `emit_step_summary_excerpt`
  (item 5), and a visible smoke path for the excerpt already exists in
  every pipeline run (it prints on every successful step). Pinning a
  cosmetic log line with a dedicated test would be coverage theater.

## Summary

- 2 weakly-covered changes strengthened with new integration tests
  (SIGINT/heartbeat).
- 1 unclear change justified inline here (pipeline bookkeeping files).
- 1 latent crash fixed (HEARTBEAT_INTERVAL clamping).
- 2 comments tightened so the 2s poll window and the `5.` regex contract
  are self-documenting.
- 1 missing help-coverage assertion added.
- 1 informational-only edit explicitly declined, with rationale.

Net change to the diff: +1 new test file, 3 new tests, +2 tightened
comments, +3 lines of config validation, +1 help-test assertion. Zero edits
removed — none of the flagged items were genuinely superfluous.

Test suite: 93 / 93 passing (was 90 / 90; 3 new tests added; PIPELINE
STEPS assertion added to an existing test).
