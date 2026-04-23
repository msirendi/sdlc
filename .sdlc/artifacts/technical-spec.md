# Technical Spec: SDLC-4 Live progress for seeded-output steps

## Summary
Make `sdlc` show visible progress while a single Claude Code step is in flight, and eliminate the false "progress" signal operators used to get from pre-existing canonical artifacts. The orchestrator must announce which canonical outputs it is tracking for the current step, log at start whether each output was already present, then emit short-cadence heartbeats that explicitly distinguish "unchanged since attempt start" (seed file from a prior run) from "updated Ns ago" (the current attempt rewrote it). Default heartbeat cadence must be short enough that targeted or follow-up runs of `02-technical-spec.md` and `08-open-pr.md` never look idle, even though `claude --print --output-format text` only emits its final response when the process exits.

## Scope boundary

### In scope
- Add tracked-output discovery and attempt-start description so the orchestrator can log, before the Claude subshell launches, which canonical file(s) the current step owns and whether they already exist on disk.
- Implement a progress renderer that compares each tracked file's mtime against the attempt's start epoch, and label files as `missing`, `unchanged since attempt start`, or `updated Ns ago`.
- Inject the progress renderer into the existing `emit_heartbeat_loop` so the periodic "still running" line now carries the tracked-output summary when the step declares one.
- Lower the default `HEARTBEAT_INTERVAL` to a short cadence (30s) and clamp non-numeric overrides so an accidentally empty `HEARTBEAT_INTERVAL=""` in `.sdlc/overrides.sh` cannot crash the heartbeat guard.
- Emit a one-line INFO from `run_claude_step` stating that Claude stdout is final-response-only in `--print` mode so operators stop waiting for streaming output.
- Introduce two portable helpers in `orchestrator/lib/common.sh` — `sdlc_file_size_bytes` and `sdlc_file_mtime_epoch` — that work on both macOS (`stat -f`) and Linux (`stat -c`) so progress lines do not depend on GNU stat.
- Document the new behavior in `README.md`, the `sdlc` help banner, and `templates/overrides-template.sh` so `HEARTBEAT_INTERVAL` is a discoverable knob.
- Add unit tests for the size/mtime helpers and an integration test that drives `sdlc` with a fake `claude` shim which seeds, then rewrites, `.sdlc/artifacts/technical-spec.md`, asserting the full `present at attempt start` → `unchanged since attempt start` → `updated` progression.

### Out of scope
- Streaming Claude's intermediate reasoning or tool-use events. The current `claude --print --output-format text` contract emits only the final response; moving to `stream-json` would cascade changes into steps 9 and 10 (which read the summary file as prose) and is deferred.
- Per-step progress for non-seeded steps. Steps that do not declare a canonical output in `STEP_REQUIRED_PATTERNS` continue to emit the plain `still running (elapsed: Ns; repo <state>)` line — adding synthetic progress there would be noise.
- Changing how attempts are retried or validated. `validate_step`, the retry budget, and the 06↔07 test-fix loop are untouched.
- Persisting progress history. Heartbeats live in the run log; no new file is written under `.sdlc/logs/`.
- A second-terminal or TUI presentation layer. The requirement is only that the default single-terminal run stays visibly alive.

## Design decisions

### Decision 1: Use file mtime vs attempt start, not file presence, as the progress signal
- Choice: For each tracked pattern, compare the newest matching file's mtime to the attempt-start epoch captured immediately before the Claude subshell is backgrounded. Files whose mtime predates that epoch are reported as `unchanged since attempt start`; files whose mtime is newer are reported as `updated Ns ago`.
- Alternatives considered: checking only file existence, hashing file contents, or requiring the step to remove the seed file at start.
- Why this wins: this is exactly the root cause the ticket calls out — `02-technical-spec.md` and `08-open-pr.md` are the only steps with pre-seeded canonical outputs, so plain presence checks are permanently "green" even during an idle Claude call. mtime vs attempt-start is cheap, portable, and does not require the agent or the operator to delete anything. Content hashing would be more robust against touch-without-change (`fsync` with same bytes), but the step-level contract is "Claude rewrites the file when it has a new spec/PR body"; if the agent writes the same bytes the operator genuinely sees no change, which is the honest signal.

### Decision 2: Capture `attempt_start_epoch` in the orchestrator, not inside `emit_heartbeat_loop`
- Choice: `execute_step_with_retries` records `attempt_start_epoch=$(date +%s)` before launching the heartbeat subshell and before `run_claude_step`, then passes it as an argument into `emit_heartbeat_loop`.
- Alternatives considered: have the heartbeat loop sample its own start time; stat the file at the beginning of each heartbeat tick.
- Why this wins: the heartbeat subshell forks after the retry loop has already accepted the attempt, so its `$SECONDS=0` does not correspond to when the agent started writing. Capturing the epoch once in the parent also guarantees the "attempt start" timestamp the `describe_tracked_outputs_at_start` summary references matches exactly the epoch used by every subsequent heartbeat tick — otherwise a tracked file updated in the first second could race the heartbeat and be reported as `unchanged`.

### Decision 3: Keep `STEP_REQUIRED_PATTERNS` as the single source of "what to track"
- Choice: Use the existing `STEP_REQUIRED_PATTERNS` map (already consumed by `validate_step`) to decide which files a step's progress lines should reference. Steps not in the map get generic heartbeats.
- Alternatives considered: add a separate `STEP_TRACKED_OUTPUTS` map; watch every file under `.sdlc/artifacts/`.
- Why this wins: `STEP_REQUIRED_PATTERNS` is the authoritative list of canonical files each step is supposed to produce. Reusing it keeps config in one place, prevents drift between "what validate enforces" and "what progress tracks," and naturally covers the two steps (02 and 08) the ticket names. Watching every artifact would produce noise on steps that incidentally touch unrelated files.

### Decision 4: Default `HEARTBEAT_INTERVAL` to 30s, clamp bad overrides to 30
- Choice: Default `HEARTBEAT_INTERVAL` to `30` and, after the default is applied, re-validate it against `^[0-9]+$`; if the current value is empty or non-numeric, reset to 30 before the main script tests `[[ "$HEARTBEAT_INTERVAL" -gt 0 ]]`.
- Alternatives considered: 60s default; leave validation out and let `[[ -gt 0 ]]` error on non-integers; fail the pipeline on a bad override.
- Why this wins: 30s is short enough that an operator watching a targeted `--only 02-technical-spec.md` run sees life within half a minute — the interval that actually matters to acceptance — while still avoiding a chatty log for slow steps that take an hour. Clamping non-integers is a defensive fix for the exact footgun a templates/overrides author hits when they uncomment `HEARTBEAT_INTERVAL=` with an empty value; a fatal error here would turn a minor override mistake into a broken run. The clamp only triggers on malformed input, so intentional overrides like `HEARTBEAT_INTERVAL=0` (disable) and `HEARTBEAT_INTERVAL=60` (slow down) are preserved.

### Decision 5: Log "Claude stdout is final-response-only" once per step from `run_claude_step`
- Choice: Emit a single INFO line from `run_claude_step` right after the existing "Timeout/Follow progress" pair, stating that Claude stdout is final-response-only in `--print` mode and that heartbeat/tracked-output lines are the live progress signal until the step exits.
- Alternatives considered: adding this to README only; printing it on every heartbeat; only printing it on the first step of a run.
- Why this wins: the misunderstanding the ticket describes is operator-per-step ("why has this step been silent for minutes?"), not operator-per-install, so surfacing it in the step header is the direct answer at the moment of confusion. Printing it on every heartbeat would bloat the log; printing it only on the first step hides it from `--only` invocations, which is the exact scenario that prompted the ticket.

### Decision 6: Keep helpers in `orchestrator/lib/common.sh` and make them portable
- Choice: Add `sdlc_file_size_bytes` (uses `wc -c` so it is uniform across BSD and GNU coreutils) and `sdlc_file_mtime_epoch` (probes `stat -f %m` then `stat -c %Y` then falls back to `0`) to `common.sh`.
- Alternatives considered: inline `stat` calls inside the heartbeat; depend on `coreutils` for `gstat`.
- Why this wins: the rest of the orchestrator already respects macOS BSD toolchains (see `sdlc_run_with_timeout`'s gtimeout/timeout/python3 ladder). Hiding the stat-flavor branching behind a helper keeps `run-pipeline.sh` readable and lets the common_unit_test.sh suite pin behavior without sourcing the whole orchestrator. Returning `0` on unreachable files means the heartbeat still renders something sensible even if the agent deleted a seed file mid-attempt.

## Change plan

1. `orchestrator/lib/common.sh`
   Add two helpers:
   - `sdlc_file_size_bytes "$path"` returns the byte count via `wc -c` and `0` for missing paths, so heartbeats can include a stable size regardless of the host `stat` dialect.
   - `sdlc_file_mtime_epoch "$path"` returns Unix epoch mtime using `stat -f %m` (BSD/macOS) first, `stat -c %Y` (GNU) as a fallback, and `0` if neither works or the file is missing. Both helpers are called per-heartbeat, so they stay free of subshells where possible.

2. `orchestrator/config.sh`
   Set `HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-30}"` and, right after, validate it against `^[0-9]+$`; if it fails, reset to `30` so the later `[[ "$HEARTBEAT_INTERVAL" -gt 0 ]]` guard in the runner never faces a non-integer. Inline comment records why (non-numeric override → fatal arithmetic error without the clamp).

3. `orchestrator/run-pipeline.sh`
   Add two helper functions used by the heartbeat pipeline:
   - `describe_tracked_outputs_at_start <step_name> <repo_root>`: looks up `STEP_REQUIRED_PATTERNS`, expands each pattern with `compgen -G`, and emits a single semicolon-joined line of the form `<pattern> missing at attempt start` or `<pattern> present at attempt start (N file(s), NB)`. Returns silently when the step declares no tracked outputs, so generic steps stay quiet.
   - `render_tracked_output_progress <step_name> <repo_root> <attempt_start_epoch>`: same pattern expansion, but emits `missing`, `unchanged since attempt start (...)`, or `updated Ns ago (...)` based on the newest matching file's mtime vs. `attempt_start_epoch`. The age is clamped to `0` when clock skew would otherwise make it negative.

4. `orchestrator/run-pipeline.sh`
   Change `emit_heartbeat_loop` to accept `step_name`, `repo_root`, and `attempt_start_epoch` as additional arguments, and to call `render_tracked_output_progress` on every tick. When the renderer returns non-empty, append `; <progress>` to the existing `still running (elapsed: Ns; repo <state>)` line; otherwise keep the pre-existing line shape so non-seeded steps are unchanged. Preserve the existing SIGTERM/SIGINT handling and the interruptible `sleep` pattern.

5. `orchestrator/run-pipeline.sh`
   In `execute_step_with_retries`, capture `attempt_start_epoch=$(date +%s)` before emitting the tracked-output announcement, call `describe_tracked_outputs_at_start` and log two INFO lines — `Tracking outputs for <label>: <description>` and a one-line explanation that progress updates compare tracked outputs against this attempt start, so pre-existing seed files remain 'unchanged' until the step rewrites them — then pass `$attempt_start_epoch` into `emit_heartbeat_loop`. The announcement only fires when tracked outputs exist, keeping generic steps clean.

6. `orchestrator/lib/execute.sh`
   Add one `sdlc_log "INFO"` line immediately after the existing "Follow progress" log that states: *Claude stdout is final-response-only in this mode; heartbeat and tracked-output lines are the live progress signals until the step exits.* This documents the `--print` contract at the moment operators are most likely to misread it.

7. `README.md`
   Update the "Default model configuration" section (or the nearest section that describes runtime behavior) to note that heartbeats fire every 30 seconds by default and include tracked artifact paths. Cross-reference `HEARTBEAT_INTERVAL` and the template override. Also add a brief mention under the operator flow that Claude's stdout appears only on step exit, so the heartbeat lines are the live signal.

8. `bin/sdlc`
   In the `DURING A RUN` help section, restate that the orchestrator prints the log path and tracked outputs when a step starts and heartbeat lines while it runs; point the operator at `tail -f` only as the optional second-terminal view, not as a required one.

9. `templates/overrides-template.sh`
   Add a commented-out `HEARTBEAT_INTERVAL=30` example and a one-sentence note explaining `0` disables the loop. This surfaces the knob to override authors without changing defaults.

10. `tests/common_unit_test.sh`
    Cover the new helpers:
    - `sdlc_file_size_bytes` returns `0` for missing paths.
    - `sdlc_file_size_bytes` returns the exact byte count for a known file.
    - `sdlc_file_mtime_epoch` returns a positive integer for an existing file.

11. `tests/config_unit_test.sh`
    Pin `HEARTBEAT_INTERVAL`:
    - Default is `30` after sourcing config.
    - An environment preset (e.g. `HEARTBEAT_INTERVAL=30` already set) wins over the default.

12. `tests/sdlc_signals_integration_test.sh`
    Add `test_tracked_output_progress_reports_seeded_artifact_then_update`:
    - Seed `.sdlc/artifacts/technical-spec.md` in a fixture repo and commit it so the artifact exists at attempt start.
    - Shim `claude` to `sleep 2`, rewrite the artifact, `sleep 2`, then print a valid `5. Status: READY` response.
    - Run `sdlc --only 02-technical-spec.md` with `HEARTBEAT_INTERVAL=1`.
    - Assert the orchestrator announces tracked outputs for Step 02, marks the artifact as `present at attempt start`, emits at least one `unchanged since attempt start` heartbeat, and emits at least one `updated` heartbeat after the shim rewrites the file.

## Edge cases and failure modes
- Edge case: the step declares a tracked pattern but nothing matches at attempt start (e.g. fresh repo, no prior run).
  Handling: `describe_tracked_outputs_at_start` reports `<pattern> missing at attempt start`; subsequent heartbeats report `<pattern> missing` until the step creates the file, at which point the first heartbeat after creation reports `updated Ns ago`.
- Edge case: the step declares a glob pattern that matches multiple files (e.g. `.sdlc/reports/semantic_diff_report_*.html`).
  Handling: the renderer sums bytes across matches and uses the newest mtime to decide `unchanged` vs `updated`. The file count is included in the parenthetical so operators can see a second file appear.
- Edge case: the step is run with `HEARTBEAT_INTERVAL=0`.
  Handling: the heartbeat loop is never started, no tracked-output line is rendered mid-step, and the attempt-start announcement still fires so the operator knows what will be written. This preserves the documented disable switch.
- Edge case: `HEARTBEAT_INTERVAL` override is empty or contains a non-integer value.
  Handling: the clamp in `config.sh` resets the variable to `30` before the `[[ -gt 0 ]]` guard, so the run proceeds with the default instead of crashing on bash arithmetic.
- Edge case: the agent writes the tracked file inside the first heartbeat interval (< `HEARTBEAT_INTERVAL` seconds after attempt start) and then exits.
  Handling: the step exits successfully without a heartbeat tick; the orchestrator still emits the final step summary and the attempt-start announcement, which is sufficient for a fast run. Progress lines are specifically there for long runs.
- Edge case: system clock changes (NTP skew) during a long run, causing `date +%s - mtime` to return negative.
  Handling: the renderer clamps `age` to `0`, so the line reads `updated 0s ago` instead of a negative number.
- Edge case: tracked file is deleted by the agent mid-attempt (e.g. rewrite-via-rename that temporarily unlinks the target).
  Handling: `compgen -G` returns no matches for that tick, and the heartbeat reports `missing`. The next tick after the rename completes reports `updated`.
- Edge case: `stat` is not available in the operator's environment (unlikely but possible on stripped containers).
  Handling: `sdlc_file_mtime_epoch` falls back to `0`, which causes every tick to report `updated Ns ago` against the attempt start (since `0 <= attempt_start_epoch`). The user loses the `unchanged` distinction but still sees the size and filename in the heartbeat.
- Failure mode: the heartbeat subshell is killed by the orchestrator's interrupt handler while rendering progress.
  Expected behavior: `stop_heartbeat` sends SIGTERM, the trap kills the pending `sleep` grandchild, and the subshell exits cleanly; the main process then continues to `terminate_current_step` as before. No change in interrupt semantics.
- Failure mode: a step declares a pattern that is not safe for `compgen -G` (contains shell metacharacters other than `*` / `?`).
  Expected behavior: `compgen -G` expansion returns nothing, the pattern is reported as `missing`, and the heartbeat stays quiet about it. The existing validate step is still the authoritative check on whether the output is acceptable at completion.

## Test strategy
- Unit coverage:
  - `tests/common_unit_test.sh` pins both new helpers: `sdlc_file_size_bytes` returns `0` for a path that does not exist, and returns the correct byte count for a file it creates in `TEST_TEMP_DIR`. `sdlc_file_mtime_epoch` returns a positive integer for an existing file. These tests live next to the existing `sdlc_lookup_kv` / `sdlc_git_has_non_log_changes` coverage because the helpers sit in the same module and have the same "foundational" character.
  - `tests/config_unit_test.sh` pins the `HEARTBEAT_INTERVAL` default to `30` and confirms an environment preset overrides the default, so heartbeat behavior is discoverable via the config suite.
- Integration coverage:
  - `tests/sdlc_signals_integration_test.sh` already drives the real `sdlc` entrypoint against a fake `claude` shim; the new test `test_tracked_output_progress_reports_seeded_artifact_then_update` extends that harness. The shim sleeps twice with a rewrite in between so the 1-second heartbeat cadence has clear windows to observe both the `unchanged` and `updated` states. Assertions cover: the "Tracking outputs for 02-technical-spec.md" start line, the `present at attempt start` label, at least one `unchanged since attempt start` heartbeat, and at least one `updated` heartbeat. Exit code is asserted `0` because the shim emits a valid `5. Status: READY` response.
  - The existing `test_heartbeat_loop_emits_still_running_line_during_step` and `test_heartbeat_interval_zero_suppresses_heartbeat_lines` remain in the suite and act as the regression guard for the generic (non-seeded) path and the disable switch.
- Fixtures, mocks, or seed data:
  - The new integration test writes `.sdlc/artifacts/technical-spec.md` with `printf '# Seed spec\n'` and commits it via `git -c user.email=... add ... commit`, so the tracked pattern matches a real file at attempt start. The fake `claude` shim is a small Bash script on `PATH` ahead of the real `claude`. No real network, LLM, or GitHub access is touched.
- Static analysis:
  - Run `shellcheck` on any changed `orchestrator/*.sh` and `orchestrator/lib/*.sh` files; any new warning is a blocker. `tests/run.sh` already shells out to every test file, so `bash tests/run.sh` becomes the final gate.

## Acceptance criteria traceability

| Acceptance criterion | Planned change | Planned test |
| --- | --- | --- |
| The root cause is documented in code comments, logs, docs, or tests closely enough that future maintainers can understand why Steps 02 and 08 looked idle. | Change plan items 2, 3, 5, 6 add inline comments (HEARTBEAT clamp, tracked-output helpers, `--print` log line) and item 7 updates `README.md` to explain the final-response-only stdout contract. | Comment audit during self-review of the spec; integration test `test_tracked_output_progress_reports_seeded_artifact_then_update` encodes the expected behavior so a regression in the explanation would show up as a failing test. |
| When a step with required outputs starts, the orchestrator logs which outputs it is tracking and whether they were already present at attempt start. | Change plan item 5 calls `describe_tracked_outputs_at_start` from `execute_step_with_retries` and logs `Tracking outputs for <label>: <description>` before launching Claude. | Integration test asserts `Tracking outputs for 02-technical-spec.md` and `present at attempt start` appear in `sdlc` output. |
| During a long-running Step 02 or Step 08 attempt, heartbeat lines report the tracked output as `unchanged since attempt start` until the step rewrites it. | Change plan items 3, 4 implement the mtime-vs-attempt-start comparison inside `render_tracked_output_progress` and wire it into `emit_heartbeat_loop`. | Integration test asserts `.sdlc/artifacts/technical-spec.md unchanged since attempt start` appears in output before the shim rewrites the file. |
| After the tracked file is rewritten during the attempt, a later heartbeat reports it as `updated`. | Change plan item 3 adds the `updated Ns ago` label; item 4 fires the renderer on every heartbeat tick so the next tick after a rewrite picks it up. | Integration test asserts `.sdlc/artifacts/technical-spec.md updated` appears in output after the shim rewrites the file. |
| Default heartbeat cadence is short enough to keep `claude --print` runs visibly alive without waiting minutes for the first heartbeat. | Change plan item 2 sets `HEARTBEAT_INTERVAL` default to `30` and clamps malformed overrides. | `tests/config_unit_test.sh` pins the default to 30 and confirms the env override path. Existing `test_heartbeat_loop_emits_still_running_line_during_step` (with `HEARTBEAT_INTERVAL=1`) guards that the loop actually fires. |
| `bash tests/run.sh` passes with new coverage for tracked-output progress. | Change plan items 10–12 add the unit and integration coverage. | Running `bash tests/run.sh` is the final gate; every test file is picked up automatically by the runner. |
| Preserve the existing step summary / artifact validation flow. | No change to `validate_step`, retry budgets, or the 06↔07 loop; `STEP_REQUIRED_PATTERNS` is reused, not altered. | Existing integration tests (`pipeline_integration_test.sh`, `execute_integration_test.sh`, validation unit tests) continue to pass unchanged. |
| Avoid adding noisy output on steps that do not declare tracked canonical outputs. | `describe_tracked_outputs_at_start` and `render_tracked_output_progress` both return silently when `STEP_REQUIRED_PATTERNS` has no entry for the step. | The existing generic heartbeat test (`test_heartbeat_loop_emits_still_running_line_during_step` against `01-branch-setup.md`, which has no tracked pattern) continues to pass with a clean, non-tracked heartbeat line. |
| Continue honoring `HEARTBEAT_INTERVAL=0` as the disable switch. | The `[[ -gt 0 ]]` guard in `run-pipeline.sh` is unchanged; config validation only rewrites non-numeric values, never `0`. | `test_heartbeat_interval_zero_suppresses_heartbeat_lines` is retained and still asserts no heartbeat lines appear when the variable is set to `0`. |
| Keep compatibility with macOS and Linux shell tooling. | `sdlc_file_mtime_epoch` branches between BSD (`stat -f %m`) and GNU (`stat -c %Y`) stat; `sdlc_file_size_bytes` uses portable `wc -c`; `compgen -G` is a bash builtin available on both OSes. | `tests/common_unit_test.sh` runs on both platforms in CI; the integration test uses only POSIX tools and bash. |

## Open questions
- None. The scope, root cause, and progress vocabulary are fully specified by the ticket, and the existing `STEP_REQUIRED_PATTERNS` map covers both steps (02 and 08) the ticket calls out.
