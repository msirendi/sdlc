# Feature: SDLC-3 CLI UX — help flag, in-run feedback, and Ctrl+C handling

## Summary
Fix three operator-facing ergonomics gaps in the `sdlc` command: there is no
first-class help screen, the terminal goes silent for minutes at a time while a
Claude step runs, and Ctrl+C does not reliably exit a running pipeline. This
change adds a user-focused `sdlc --help` (and `sdlc --version`), a heartbeat
and follow-along tail hint during each step, a short "Status:" summary line on
step completion, and a SIGINT/SIGTERM trap that walks the Claude subshell's
process tree to terminate it cleanly before the orchestrator exits 130.

## Requirements
- `sdlc --help` and `sdlc -h` must print a user-facing overview (usage,
  typical flow, pipeline step map, during-a-run behavior, artifacts/logs
  layout, companion commands) without invoking the orchestrator. It must work
  even when the caller is not inside a git repository.
- `sdlc --version` must print the install location (`SDLC_HOME`) and current
  revision so operators can confirm which checkout is on `PATH`.
- When a Claude step starts, the orchestrator must print a
  `Follow progress: tail -f <log>` hint so operators can watch progress in a
  second terminal.
- While a Claude step is running, the orchestrator must emit periodic
  heartbeat log lines (`<step> still running (elapsed: Ns)`) so long steps
  are not silent. The cadence is driven by a new `HEARTBEAT_INTERVAL`
  configuration knob (seconds), with `0` disabling heartbeats.
- When a step completes successfully, the orchestrator must print a
  one-line excerpt from the step summary (the canonical `Status:` line).
- Pressing Ctrl+C while `sdlc` is running must:
  1. Terminate the currently-executing Claude step (and every descendant
     process it spawned — the `tee` helpers, the `timeout` wrapper, the
     Claude CLI, and any of its children).
  2. Stop the heartbeat loop cleanly.
  3. Exit the orchestrator with status `130` (the conventional shell
     SIGINT exit code).
  4. Leave no orphan `claude` or `sleep` processes behind.
- New behavior must be covered by automated tests in the existing
  `tests/` suite.

## Technical Constraints
- Preserve the current Bash-based orchestrator architecture and wrapper
  layout under `bin/`.
- Must work on macOS (the primary operator platform) without requiring GNU
  coreutils. The process-tree walk must use `pgrep -P`, which is available
  on both macOS and Linux.
- The existing `--output-format text` contract for the Claude invocation
  must be preserved — downstream steps 9 and 10 read the summary file as
  prose, so the stdout pipeline must continue to tee Claude's stdout
  verbatim into the summary file.
- The interrupt trap must tolerate being invoked when `CURRENT_STEP_PID`
  is unset (no active step) and when the backgrounded subshell has already
  exited.
- Backgrounding the Claude subshell (so `wait` is signal-interruptible)
  must not change the observable exit-code propagation that the retry loop
  in `run-pipeline.sh` depends on.
- Subshell-internal bash job-termination notices (e.g. `Terminated: 15`)
  must not clutter the operator's terminal; they may be logged to the
  per-step log file instead.

## Acceptance Criteria
- `sdlc --help` exits 0 and includes `USAGE`, `TYPICAL FLOW`, `PIPELINE STEPS`,
  `DURING A RUN`, and cross-references to `sdlc-status`.
- `sdlc -h` behaves identically to `sdlc --help`.
- `sdlc --help` succeeds even when invoked outside a git repository.
- `sdlc --version` exits 0 and includes `sdlc (SDLC_HOME=`.
- `HEARTBEAT_INTERVAL` defaults to `120` seconds and can be overridden via
  environment variable or `.sdlc/overrides.sh`.
- During a step, the orchestrator log contains a `Follow progress: tail -f`
  line and periodic `still running (elapsed: Ns)` lines at the configured
  cadence.
- On successful step completion, the orchestrator log contains a
  `<step>: Status: READY` line sourced from the step summary.
- Under a PTY, sending SIGINT to `sdlc` during a step exits with code 130,
  leaves no lingering `claude` / `sleep` descendants, and prints an
  `Interrupt received. Terminating current step and exiting...` warning.
- The existing test suite still passes, plus new tests cover the `--help`,
  `-h`, `--version`, and `HEARTBEAT_INTERVAL` contracts.

## Files Likely Affected
- `bin/sdlc`
- `orchestrator/run-pipeline.sh`
- `orchestrator/lib/execute.sh`
- `orchestrator/config.sh`
- `tests/bin_wrappers_unit_test.sh`
- `tests/config_unit_test.sh`

## Open Questions
- None. The scope is the three operator-facing gaps enumerated above.
