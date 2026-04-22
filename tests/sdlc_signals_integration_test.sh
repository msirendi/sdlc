#!/usr/bin/env bash
# Integration tests for the SDLC-3 operator-ergonomics contracts that unit
# tests cannot exercise in isolation: the heartbeat loop must actually fire
# while a step is in flight, and Ctrl+C must propagate to the backgrounded
# Claude subshell and every descendant it spawned.
#
# These tests drive the real `sdlc` wrapper against a fake `claude` shim so
# the backgrounded-subshell + signal-trap + pgrep walk are all exercised
# end-to-end. A unit-only test would bypass the bash job-control behavior
# that broke Ctrl+C in the first place.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./testlib.sh
. "$TESTS_DIR/testlib.sh"

BIN_DIR="$REPO_ROOT/bin"

# Set up a target git repo + task file + fake claude shim, and return the
# environment array the test should pass to `env`. Caller sets PATH/HOME first
# via the caller-supplied arrays. $1 is the shim body (content of the `claude`
# command on PATH); $2 is the target-repo subdirectory name.
setup_signal_fixture() {
  local shim_body="$1"
  local repo_subdir="$2"

  use_temp_dir
  TARGET_REPO="$TEST_TEMP_DIR/$repo_subdir"
  SHIM_DIR="$TEST_TEMP_DIR/shims-$repo_subdir"
  create_git_repo "$TARGET_REPO"
  git -C "$TARGET_REPO" -c user.email=test@example.com -c user.name=Test \
    commit --allow-empty -q -m "init"

  # A task file is not strictly required, but the pipeline logs a WARN without
  # one. Providing a stub keeps the captured output readable in failures.
  mkdir -p "$TARGET_REPO/.sdlc"
  printf '# Task\nSignal/heartbeat test fixture.\n' > "$TARGET_REPO/.sdlc/task.md"

  mkdir -p "$SHIM_DIR"
  printf '%s\n' "$shim_body" > "$SHIM_DIR/claude"
  chmod +x "$SHIM_DIR/claude"
}

test_heartbeat_loop_emits_still_running_line_during_step() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  # Shim sleeps 3 seconds before returning a valid Status line, giving the
  # 1-second heartbeat cadence at least two chances to fire during the step.
  setup_signal_fixture '#!/usr/bin/env bash
sleep 3
printf "5. Status: READY\n"' "hb-target"

  local output
  local status=0
  output=$(env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:$SHIM_DIR:/usr/bin:/bin" \
    HEARTBEAT_INTERVAL=1 \
    INTER_STEP_DELAY=0 \
    sdlc "$TARGET_REPO" --only 01-branch-setup.md 2>&1) || status=$?

  # The step itself may report BLOCKED through the validator (the shim does no
  # real branch work) — what we care about is that the heartbeat line appears
  # while the step is running, so the exit code is intentionally not asserted.
  assert_contains "$output" "still running (elapsed:" \
    "Expected a heartbeat 'still running (elapsed: Ns)' line while the step was in flight. Output: $output"
}

test_heartbeat_interval_zero_suppresses_heartbeat_lines() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  # Same 3-second shim, but HEARTBEAT_INTERVAL=0 must disable the loop entirely.
  setup_signal_fixture '#!/usr/bin/env bash
sleep 3
printf "5. Status: READY\n"' "hb-off-target"

  local output
  local status=0
  output=$(env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:$SHIM_DIR:/usr/bin:/bin" \
    HEARTBEAT_INTERVAL=0 \
    INTER_STEP_DELAY=0 \
    sdlc "$TARGET_REPO" --only 01-branch-setup.md 2>&1) || status=$?

  assert_not_contains "$output" "still running (elapsed:" \
    "Did not expect heartbeat lines when HEARTBEAT_INTERVAL=0. Output: $output"
}

test_sdlc_terminate_signal_exits_130_and_kills_claude_descendants() {
  # NOTE ON SIGNAL CHOICE: the orchestrator traps `INT TERM` with the same
  # `handle_interrupt` function — terminate the step, stop heartbeats, exit
  # 130 — so this test exercises that exact machinery via SIGTERM rather
  # than SIGINT. This is a test-harness constraint, not a scope reduction:
  # a non-interactive bash parent (like `run.sh`) installs SIG_IGN on SIGINT
  # for its `&`-backgrounded children, which silently swallows any explicit
  # `kill -INT` the test would send. SIGTERM is delivered normally. macOS
  # lacks `setsid`, so there is no portable way to re-enable SIGINT here.
  # The user-facing Ctrl+C path (terminal-driven SIGINT to a foreground sdlc
  # process) is not subject to SIG_IGN and follows the same trap.
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v pgrep >/dev/null 2>&1; then
    printf 'SKIP - pgrep not available\n' >&2
    return 0
  fi

  use_temp_dir
  local pid_file="$TEST_TEMP_DIR/claude-shim.pid"
  # Shim records its own pid (which, after `exec`, becomes the `sleep 47`'s
  # pid) to a file so the test can poll for readiness synchronously — stdout
  # from the shim would be buffered inside Claude's two-tee pipeline and not
  # visible to the orchestrator's caller until the pipeline drains at exit.
  # After the signal the test can also check whether that pid is still alive;
  # a leaked sleep means signal_process_tree failed to walk the tree.
  local shim_body
  # shellcheck disable=SC2016
  shim_body=$(cat <<SHIM
#!/usr/bin/env bash
echo \$\$ > "$pid_file"
# exec replaces this shell with sleep, so \$\$ in the file above is the sleep's
# pid. 47 is distinctive (not a rounded cadence used anywhere else in the
# orchestrator) and long enough to outlast the test's interrupt-wait loop.
exec sleep 47
SHIM
)

  TARGET_REPO="$TEST_TEMP_DIR/sigint-target"
  SHIM_DIR="$TEST_TEMP_DIR/shims-sigint"
  create_git_repo "$TARGET_REPO"
  git -C "$TARGET_REPO" -c user.email=test@example.com -c user.name=Test \
    commit --allow-empty -q -m "init"
  mkdir -p "$TARGET_REPO/.sdlc" "$SHIM_DIR"
  printf '# Task\nSIGINT test fixture.\n' > "$TARGET_REPO/.sdlc/task.md"
  printf '%s\n' "$shim_body" > "$SHIM_DIR/claude"
  chmod +x "$SHIM_DIR/claude"

  local outfile="$TEST_TEMP_DIR/sigint.out"

  # Start sdlc in the background. HEARTBEAT_INTERVAL=0 keeps the output focused
  # on the interrupt path; INTER_STEP_DELAY=0 avoids trailing sleeps if the step
  # returned normally (which it will not, because we SIGINT before that).
  env -i \
    HOME="$TEST_TEMP_DIR/home" \
    PATH="$BIN_DIR:$SHIM_DIR:/usr/bin:/bin" \
    HEARTBEAT_INTERVAL=0 \
    INTER_STEP_DELAY=0 \
    sdlc "$TARGET_REPO" --only 01-branch-setup.md >"$outfile" 2>&1 &
  local sdlc_pid=$!

  # Wait up to 15 seconds for the shim to write its pid file — that is the
  # moment we know the backgrounded subshell exists and CURRENT_STEP_PID is
  # populated. Signalling earlier would race the orchestrator's argument
  # parsing and not exercise the contract under test.
  local waited=0
  while [[ "$waited" -lt 150 ]] && [[ ! -s "$pid_file" ]]; do
    sleep 0.1
    waited=$((waited + 1))
  done

  if [[ ! -s "$pid_file" ]]; then
    kill -KILL "$sdlc_pid" 2>/dev/null || true
    wait "$sdlc_pid" 2>/dev/null || true
    fail "claude shim never wrote its pid file within 15s. Output: $(cat "$outfile" 2>/dev/null || printf '(empty)\n')"
    return 1
  fi

  local claude_pid
  claude_pid=$(cat "$pid_file")

  # See the NOTE ON SIGNAL CHOICE at the top of this function — TERM exercises
  # the same `handle_interrupt` path as Ctrl+C-driven INT.
  kill -TERM "$sdlc_pid"

  # Wait up to 10 seconds for sdlc to exit. The TERM→KILL escalation inside
  # terminate_current_step is 2s, plus cleanup; 10s is comfortable headroom.
  local exit_waited=0
  while [[ "$exit_waited" -lt 100 ]] && kill -0 "$sdlc_pid" 2>/dev/null; do
    sleep 0.1
    exit_waited=$((exit_waited + 1))
  done

  wait "$sdlc_pid" 2>/dev/null
  local exit_status=$?

  if [[ "$exit_status" -ne 130 ]]; then
    kill -KILL "$claude_pid" 2>/dev/null || true
    fail "sdlc should exit 130 on terminate signal during a running step; got [$exit_status]. Output: $(cat "$outfile")"
    return 1
  fi

  if ! grep -q "Interrupt received" "$outfile"; then
    kill -KILL "$claude_pid" 2>/dev/null || true
    fail "Expected the handle_interrupt WARN banner. Output: $(cat "$outfile")"
    return 1
  fi

  # The whole point of signal_process_tree is that the backgrounded subshell's
  # descendants (timeout wrapper → sleep 47) do not survive the orchestrator's
  # exit. Give the tree-walk a brief moment to reap before checking.
  sleep 0.3
  if kill -0 "$claude_pid" 2>/dev/null; then
    kill -KILL "$claude_pid" 2>/dev/null || true
    fail "claude descendant pid $claude_pid (sleep 47) was still alive after the interrupt. Output: $(cat "$outfile")"
    return 1
  fi
}

run_test_suite
