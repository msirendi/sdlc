Fixes #SDLC-3

## Summary
Closes three operator-facing ergonomics gaps in the `sdlc` command that
together made a pipeline run feel opaque and unsafe to interrupt: there
was no first-class help screen, the terminal went silent for minutes at
a time while a Claude step ran, and Ctrl+C did not reliably exit — it
would usually leave `claude` / `sleep` / `timeout` / `tee` descendants
running in the background while the operator's shell returned. This PR
adds a user-focused `sdlc --help` (plus `-h` and `--version`) that works
outside a git repo, prints a `tail -f <log>` follow-along hint and
periodic "still running (elapsed: Ns)" heartbeats during each step, emits
a one-line `Status:` excerpt on successful step completion, and installs
a SIGINT/SIGTERM trap that walks the Claude subshell's process tree via
`pgrep -P`, TERM/KILL-escalates every descendant, and exits 130.

## Changes
- **`sdlc --help` / `-h` / `--version`:** `bin/sdlc` now intercepts these
  flags before it ever sources the orchestrator or checks for a git repo,
  so help is available to first-time operators and outside a repo. The
  help screen covers USAGE, TYPICAL FLOW, PIPELINE STEPS, DURING A RUN
  (including Ctrl+C behavior), artifacts/logs layout, and cross-references
  `sdlc-status` / `sdlc-dry` / `sdlc-init`. `--version` prints
  `sdlc (SDLC_HOME=<path>, rev=<sha>)` so operators can confirm which
  checkout is on `PATH`.
- **Config knob:** `orchestrator/config.sh` adds `HEARTBEAT_INTERVAL`
  (default `120`, `0` disables) as an environment-overridable cadence for
  the in-run progress log lines.
- **In-run feedback:** `orchestrator/lib/execute.sh` prints a
  `Follow progress: tail -f <log>` hint when a Claude step starts, spawns
  a background heartbeat that emits `<step> still running (elapsed: Ns)`
  every `HEARTBEAT_INTERVAL` seconds, and on successful completion extracts
  and logs the canonical `Status:` line from the step summary.
- **Ctrl+C handling:** `orchestrator/run-pipeline.sh` installs a SIGINT/
  SIGTERM trap that tolerates `CURRENT_STEP_PID` being unset, walks the
  backgrounded Claude subshell's descendant tree with `pgrep -P`
  (macOS-safe, no GNU coreutils required), sends TERM then KILL, reaps the
  subshell via `wait`, and exits 130. The Claude invocation is now run in
  a backgrounded subshell so bash's `wait` is signal-interruptible without
  changing the exit-code propagation that the retry loop depends on; the
  subshell's own stderr is redirected into the per-step log so bash's
  `Terminated: 15` notice does not clutter the operator's terminal.
- **Tests:** `tests/bin_wrappers_unit_test.sh` adds three cases pinning
  the `--help` / `-h` / `--version` contracts and confirming `--help`
  works outside a git repo. `tests/config_unit_test.sh` adds two cases
  pinning the `HEARTBEAT_INTERVAL` default and environment-override
  behavior.

## How to test
1. **Prerequisites:** `bash`, `git`, `pgrep`, and a POSIX `timeout`/
   `gtimeout` on `PATH`. No external services or Anthropic credentials
   are required — integration tests shim the `claude` CLI.
2. **Run the full suite:** `bash tests/run.sh`.
   Expected: 90 tests pass across 10 suites, exit 0. Matches
   `.sdlc/artifacts/test-results.md`.
3. **`--help` contract:** `bin/sdlc --help` and `bin/sdlc -h`.
   Expected: exit 0; output contains `USAGE`, `TYPICAL FLOW`,
   `PIPELINE STEPS`, `DURING A RUN`, and a reference to `sdlc-status`.
4. **`--help` outside a git repo:** `cd /tmp && bin/sdlc --help`.
   Expected: exit 0 with the same help screen — the help screen must not
   require a git repository.
5. **`--version` contract:** `bin/sdlc --version`.
   Expected: exit 0; output contains `sdlc (SDLC_HOME=` followed by an
   absolute path and a revision marker.
6. **Heartbeat default:** `bash tests/config_unit_test.sh`.
   Expected: `HEARTBEAT_INTERVAL` defaults to `120` and honors an
   environment override (e.g. `HEARTBEAT_INTERVAL=30`).
7. **In-run feedback (smoke, optional):** against a target repo, run
   `sdlc --only 02-technical-spec.md` with `HEARTBEAT_INTERVAL=5` in the
   environment. Expected: orchestrator log contains a
   `Follow progress: tail -f` line, multiple
   `02-technical-spec.md still running (elapsed: Ns)` lines at ~5s
   cadence, and on success a single
   `02-technical-spec.md: Status: READY` line.
8. **Ctrl+C contract (manual, optional):** under a PTY, run `sdlc`
   against a target repo, press Ctrl+C while a Claude step is active.
   Expected: exit code `130`, an
   `Interrupt received. Terminating current step and exiting...`
   warning, and `pgrep -a claude` / `pgrep -a sleep` show no
   orchestrator-owned descendants left behind.

## Risks and considerations
- **Backgrounded Claude subshell changes signal plumbing, not exit-code
  propagation:** the retry loop in `run-pipeline.sh` still observes the
  same numeric status from the subshell as before (this is what made
  `wait` usable inside the trap). If a future refactor reintroduces a
  foreground `eval` for the Claude call, the SIGINT handler will regress
  back to "Ctrl+C returns the shell but leaves descendants running" —
  the trap is only useful because `wait` is interruptible.
- **Process-tree walk is breadth-first via `pgrep -P`:** this is portable
  (macOS + Linux) but depends on `pgrep` being on `PATH`. If an operator
  ships a stripped-down base image without `procps`/`pgrep`, the trap will
  still send TERM to the direct subshell PID and exit 130, but deeper
  descendants (the `timeout` wrapper, the Claude CLI, any of its children)
  could survive. This is an acceptable trade-off for the primary operator
  platform (macOS); if we later support minimal Linux containers, the
  trap needs a `/proc/*/task/*/children` fallback.
- **Heartbeat is a log line, not a spinner:** by design — `sdlc` is
  typically redirected to a log file, and a TTY spinner would corrupt
  captured output. Operators who want interactive progress should
  `tail -f` the per-step log using the printed hint. Setting
  `HEARTBEAT_INTERVAL=0` in `.sdlc/overrides.sh` silences the heartbeat
  without disabling the `tail -f` hint or the `Status:` summary line.
- **`Status:` extraction is a regex on the step summary:** the one-line
  summary printed on success is sourced from the canonical `Status:`
  line in the per-step summary file. If a step ever drops that line
  (e.g., a step author writes `Result:` instead), the orchestrator
  will simply omit the summary line — no failure, but the operator
  loses the at-a-glance confirmation. Every current step already prints
  `Status: READY` as its final section, so this is a forward-compat note,
  not a live concern.
- **Terminal cleanliness relies on redirecting the subshell's stderr into
  the per-step log:** if a future change reinstates the subshell's stderr
  to the terminal (e.g., for debugging), the operator will see bash's
  `Terminated: 15` notice on Ctrl+C again. The current redirection is
  intentional and load-bearing for a clean interrupt UX.
