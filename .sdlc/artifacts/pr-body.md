Fixes #SDLC-4

## Summary
Makes `sdlc` show visible progress while a Claude step is in flight, and
removes the false "progress" signal that pre-seeded canonical artifacts used
to provide. Before this change, targeted or follow-up runs of
`02-technical-spec.md` and `08-open-pr.md` looked idle for minutes at a time
— the root cause is that `claude --print --output-format text` only emits
its final response when the process exits, and those two steps already had
the canonical artifact on disk from prior runs, so neither stdout nor file
presence gave an honest "is something happening?" signal. The orchestrator
now announces tracked canonical outputs at attempt start, labels each file
as `missing`, `present at attempt start`, `unchanged since attempt start`, or
`updated Ns ago` in every heartbeat, and the default heartbeat cadence drops
from 120s to 30s so `--print` runs stay visibly alive without a second
terminal.

## Changes
- **Config (`orchestrator/config.sh`):** `HEARTBEAT_INTERVAL` default drops
  from `120` to `30`; the existing non-numeric clamp now resets malformed
  overrides to `30` as well, so an empty `HEARTBEAT_INTERVAL=` in
  `overrides.sh` cannot crash the `[[ -gt 0 ]]` guard downstream.
  `HEARTBEAT_INTERVAL=0` still disables heartbeats.
- **Portable filesystem helpers (`orchestrator/lib/common.sh`):** adds
  `sdlc_file_size_bytes` (portable `wc -c`, returns `0` for missing paths)
  and `sdlc_file_mtime_epoch` (BSD `stat -f %m` then GNU `stat -c %Y`, with
  a `0` fallback), so the progress renderer does not depend on GNU coreutils
  on macOS.
- **Tracked-output progress (`orchestrator/run-pipeline.sh`):** adds
  `describe_tracked_outputs_at_start` and `render_tracked_output_progress`,
  both driven by the existing `STEP_REQUIRED_PATTERNS` map.
  `execute_step_with_retries` now captures an `attempt_start_epoch` before
  the Claude subshell launches, logs which outputs it is tracking and
  whether they were already present, and passes the epoch into
  `emit_heartbeat_loop`. Each heartbeat tick appends a `; <pattern>
  unchanged since attempt start | updated Ns ago (...)` suffix to the
  existing `still running (elapsed: Ns; repo <state>)` line; steps without
  tracked patterns emit the unchanged pre-existing line.
- **`--print` contract is explicit (`orchestrator/lib/execute.sh`):** the
  step header now includes a single INFO line stating that Claude stdout is
  final-response-only in `--print` mode and that heartbeat / tracked-output
  lines are the live progress signal until the step exits. Surfacing this at
  the moment operators hit confusion (not just in the README) is a direct
  fix for the "why has this been silent for minutes?" misread.
- **Docs & discoverability (`README.md`, `bin/sdlc`,
  `templates/overrides-template.sh`):** README explains the 30s default and
  that tracked artifact paths appear in heartbeats. `sdlc --help`'s
  `DURING A RUN` section now says Claude's response prints on exit and that
  the start line includes tracked outputs. The overrides template adds a
  commented-out `HEARTBEAT_INTERVAL=30` example so the knob is
  discoverable.
- **Tests (`tests/common_unit_test.sh`, `tests/config_unit_test.sh`,
  `tests/sdlc_signals_integration_test.sh`):** pins the new helpers
  (`0` for missing path, positive-integer mtime for a created file), pins
  the 30s `HEARTBEAT_INTERVAL` default, and adds
  `test_tracked_output_progress_reports_seeded_artifact_then_update` which
  drives the real `sdlc` entrypoint against a fake `claude` shim that
  seeds, then rewrites, `.sdlc/artifacts/technical-spec.md`, asserting the
  full `present at attempt start` → `unchanged since attempt start` →
  `updated` progression.

## How to test
1. **Prerequisites:** `bash`, `git`, and either BSD or GNU `stat` on `PATH`
   (both macOS and Linux tool dialects are covered). No external services
   or Anthropic credentials are required — the integration test shims the
   `claude` CLI.
2. **Run the full suite:** `bash tests/run.sh`.
   Expected: 96 tests pass across 11 suites, exit 0. Matches
   `.sdlc/artifacts/test-results.md`.
3. **Heartbeat default:** `bash tests/config_unit_test.sh`.
   Expected: `HEARTBEAT_INTERVAL` now defaults to `30` and an environment
   preset still wins.
4. **Tracked-output progress (integration):**
   `bash tests/sdlc_signals_integration_test.sh`.
   Expected: the new
   `test_tracked_output_progress_reports_seeded_artifact_then_update` case
   passes, asserting all four progress-line shapes (`Tracking outputs for
   02-technical-spec.md`, `present at attempt start`, `unchanged since
   attempt start`, `updated`).
5. **Portable filesystem helpers (unit):**
   `bash tests/common_unit_test.sh`.
   Expected: `sdlc_file_size_bytes` returns `0` for a missing path and the
   exact byte count for a known file; `sdlc_file_mtime_epoch` returns a
   positive integer for an existing file. Works on both macOS (BSD `stat`)
   and Linux (GNU `stat`).
6. **Smoke (optional, against a target repo):** run
   `sdlc --only 02-technical-spec.md` with a pre-existing
   `.sdlc/artifacts/technical-spec.md` and `HEARTBEAT_INTERVAL=5` in the
   environment. Expected: log contains `Tracking outputs for
   02-technical-spec.md: .sdlc/artifacts/technical-spec.md present at
   attempt start (...)`, then multiple
   `... still running (elapsed: Ns; repo ...; .sdlc/artifacts/technical-spec.md unchanged since attempt start ...)`
   lines, and after Claude rewrites the file a later heartbeat reporting
   `.sdlc/artifacts/technical-spec.md updated Ns ago (...)`.
7. **Disable switch still works:** `HEARTBEAT_INTERVAL=0 sdlc --only
   01-branch-setup.md`. Expected: no heartbeat lines and no tracked-output
   mid-run lines; the step still runs to completion.

## Risks and considerations
- **Progress signal is mtime-vs-attempt-start, not content hashing.** If a
  step rewrites the tracked artifact with byte-identical content, the
  heartbeat will correctly report `updated` because mtime changed — but a
  `touch`-style no-op write would also flip the label. This is an accepted
  trade-off: the step contract is "Claude rewrites the file when it has a
  new spec/PR body," and a more robust hash-based signal would add per-tick
  I/O for no real-world gain. If a future step starts `touch`-ing
  pre-existing artifacts for unrelated reasons, the label will lie.
- **`HEARTBEAT_INTERVAL` default is now 30s (was 120s).** Logs for
  multi-hour runs will be four times as chatty by default. Operators who
  redirect `sdlc` to a file and care about log size can set
  `HEARTBEAT_INTERVAL=120` (or higher) in `.sdlc/overrides.sh` to restore
  the prior cadence; the knob is now explicitly surfaced in the overrides
  template. `HEARTBEAT_INTERVAL=0` is still the documented disable switch
  and is preserved by the non-numeric clamp (only empty/non-integer values
  are rewritten).
- **`stat` portability fallback is a silent degradation.** On a stripped
  container without any `stat` at all, `sdlc_file_mtime_epoch` returns `0`
  and every tick reports `updated Ns ago` (since `0 <= attempt_start_epoch`
  is never true once `date +%s` has advanced). The operator loses the
  `unchanged` distinction but the heartbeat still renders filenames and
  sizes. `wc -c` is POSIX and does not share this risk.
- **Progress renderer reuses `STEP_REQUIRED_PATTERNS`**, so the two steps
  the ticket calls out (`02-technical-spec.md`, `08-open-pr.md`) are
  covered, plus any other step that declares a canonical output (e.g.
  `05-commit.md`, `09-semantic-review.md`,
  `10-semantic-diff-report.md`). Steps with no declared pattern stay on
  the pre-existing generic heartbeat line — no new noise there.
- **Not yet addressed:** streaming Claude's intermediate reasoning/tool-use
  events. That would require moving off `claude --print --output-format
  text` to `stream-json`, which cascades changes into steps 9 and 10
  (which currently read the summary file as prose) and is explicitly out
  of scope for this ticket. The heartbeat + tracked-output pair is the
  closest non-streaming analogue available under the current `--print`
  contract.
- **Reviewer scrutiny requested on:** (a) the `emit_heartbeat_loop`
  signature change — the two callers are updated in lockstep, but any
  downstream override that wraps it will need to be updated; (b) whether
  30s is the right default for teams that redirect `sdlc` to CI logs.
