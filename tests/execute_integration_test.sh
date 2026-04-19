#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"

# These integration tests exercise run_claude_step end-to-end with a stubbed
# `claude` CLI on PATH. The stub records its argv and stdin so tests can assert
# on how the Claude Code runner is invoked — this is the behavior that replaced
# the old Codex CLI call path on this branch.

load_execute_environment() {
  SDLC_HOME="$REPO_ROOT"
  # shellcheck source=orchestrator/config.sh
  source "$REPO_ROOT/orchestrator/config.sh"
  # shellcheck source=orchestrator/lib/common.sh
  source "$REPO_ROOT/orchestrator/lib/common.sh"
  # shellcheck source=orchestrator/lib/execute.sh
  source "$REPO_ROOT/orchestrator/lib/execute.sh"
}

setup_execute_fixture() {
  use_temp_dir

  FAKE_REPO="$TEST_TEMP_DIR/target-repo"
  FAKE_BIN="$TEST_TEMP_DIR/bin"
  STEP_FILE="$TEST_TEMP_DIR/05-tests.md"
  TASK_FILE="$TEST_TEMP_DIR/task.md"
  CONTEXT_FILE="$TEST_TEMP_DIR/pipeline-context.md"
  STEP_LOG_FILE="$TEST_TEMP_DIR/step.log"
  STEP_SUMMARY_FILE="$TEST_TEMP_DIR/step_summary.md"
  CLAUDE_ARGS_FILE="$TEST_TEMP_DIR/claude.args"
  CLAUDE_STDIN_FILE="$TEST_TEMP_DIR/claude.stdin"
  # The sdlc_log helper appends to $LOG_FILE when it is set, so route those
  # orchestrator-style log lines away from the test assertions.
  LOG_FILE="$TEST_TEMP_DIR/orchestrator.log"

  create_git_repo "$FAKE_REPO"
  mkdir -p "$FAKE_BIN"

  cat <<'EOF' > "$STEP_FILE"
# Step 5 — Implement Thorough Unit and Integration Tests

**Mode:** Automated
Execute unit and integration tests.
EOF

  cat <<'EOF' > "$TASK_FILE"
# Feature: Validate staged Claude runner
Build high-value tests that exercise the Claude CLI runner path.
EOF

  : > "$CONTEXT_FILE"
  : > "$STEP_LOG_FILE"
  : > "$STEP_SUMMARY_FILE"
  : > "$LOG_FILE"

  # Default stub records argv + stdin and prints a READY response. Individual
  # tests can overwrite it (e.g., to simulate a failing claude invocation).
  write_claude_stub "$CLAUDE_ARGS_FILE" "$CLAUDE_STDIN_FILE" 0
  PATH="$FAKE_BIN:$PATH"
  export PATH

  STEP_PERMISSION_MODES=()
  CLAUDE_EXTRA_ARGS=""
}

write_claude_stub() {
  local args_file="$1"
  local stdin_file="$2"
  local exit_code="$3"

  cat <<STUB > "$FAKE_BIN/claude"
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$args_file"
cat > "$stdin_file"
printf '1. Accomplished\n- Step executed under stub.\n5. Status: READY\n'
exit $exit_code
STUB
  chmod +x "$FAKE_BIN/claude"
}

invoke_run_claude_step() {
  # Use a generous timeout so sdlc_run_with_timeout does not interfere with fast
  # stub invocations, but keep it short enough to catch wedged tests.
  set +e
  run_claude_step \
    "$STEP_FILE" \
    "$TASK_FILE" \
    "$CONTEXT_FILE" \
    "$FAKE_REPO" \
    "$STEP_LOG_FILE" \
    "$STEP_SUMMARY_FILE" \
    60 \
    >/dev/null
  local status=$?
  set -e
  RUN_CLAUDE_STATUS="$status"
}

test_run_claude_step_invokes_claude_with_configured_flags() {
  load_execute_environment
  setup_execute_fixture
  CLAUDE_MODEL="claude-opus-4-7"
  CLAUDE_EFFORT="xhigh"
  CLAUDE_PERMISSION_MODE="acceptEdits"
  CLAUDE_OUTPUT_FORMAT="text"

  invoke_run_claude_step
  assert_exit_code 0 "$RUN_CLAUDE_STATUS" "Expected run_claude_step to return the stub's exit code."

  local args
  args=$(cat "$CLAUDE_ARGS_FILE")
  assert_contains "$args" "--print" "Expected --print to be passed so the final Claude response is captured."
  assert_contains "$args" "--model"$'\n'"claude-opus-4-7" \
    "Expected --model to be followed by the configured CLAUDE_MODEL."
  assert_contains "$args" "--effort"$'\n'"xhigh" \
    "Expected --effort to be followed by the configured CLAUDE_EFFORT."
  assert_contains "$args" "--permission-mode"$'\n'"acceptEdits" \
    "Expected --permission-mode to use the configured default."
  assert_contains "$args" "--output-format"$'\n'"text" \
    "Expected --output-format to be passed with the configured value."
}

test_run_claude_step_applies_per_step_permission_mode_override() {
  load_execute_environment
  setup_execute_fixture
  STEP_PERMISSION_MODES=("05-tests.md=plan")

  invoke_run_claude_step
  assert_exit_code 0 "$RUN_CLAUDE_STATUS" "Expected override invocation to succeed."

  local args
  args=$(cat "$CLAUDE_ARGS_FILE")
  assert_contains "$args" "--permission-mode"$'\n'"plan" \
    "Expected per-step STEP_PERMISSION_MODES entry to override the default mode."
  assert_not_contains "$args" "--permission-mode"$'\n'"acceptEdits" \
    "Did not expect acceptEdits to be passed once the per-step override was configured."
}

test_run_claude_step_forwards_claude_extra_args() {
  load_execute_environment
  setup_execute_fixture
  CLAUDE_EXTRA_ARGS="--max-turns 40 --max-budget-usd 10.00"

  invoke_run_claude_step
  assert_exit_code 0 "$RUN_CLAUDE_STATUS" "Expected invocation with extra args to succeed."

  local args
  args=$(cat "$CLAUDE_ARGS_FILE")
  assert_contains "$args" "--max-turns"$'\n'"40" \
    "Expected CLAUDE_EXTRA_ARGS to forward --max-turns with its value as separate argv entries."
  assert_contains "$args" "--max-budget-usd"$'\n'"10.00" \
    "Expected CLAUDE_EXTRA_ARGS to forward --max-budget-usd with its value."
}

test_run_claude_step_passes_full_prompt_on_stdin() {
  load_execute_environment
  setup_execute_fixture

  invoke_run_claude_step
  assert_exit_code 0 "$RUN_CLAUDE_STATUS" "Expected invocation to succeed."

  local stdin_contents
  stdin_contents=$(cat "$CLAUDE_STDIN_FILE")
  assert_contains "$stdin_contents" "Repository root: $FAKE_REPO" \
    "Expected the prompt to identify the repository root."
  assert_contains "$stdin_contents" "Build high-value tests that exercise the Claude CLI runner path." \
    "Expected the task description to be injected into the prompt."
  assert_contains "$stdin_contents" "Execute unit and integration tests." \
    "Expected the step instructions to be injected into the prompt."
  assert_contains "$stdin_contents" "## Final Response Format" \
    "Expected the canonical final response format to be included in the prompt."
}

test_run_claude_step_copies_stub_output_to_log_and_summary() {
  load_execute_environment
  setup_execute_fixture

  invoke_run_claude_step
  assert_exit_code 0 "$RUN_CLAUDE_STATUS" "Expected the stubbed step to succeed."

  local log_contents summary_contents
  log_contents=$(cat "$STEP_LOG_FILE")
  summary_contents=$(cat "$STEP_SUMMARY_FILE")

  assert_contains "$log_contents" "Status: READY" \
    "Expected the step log to contain the stub's final status line."
  assert_contains "$summary_contents" "Status: READY" \
    "Expected the summary file to be a copy of the step log for downstream validation."
  assert_equals "$log_contents" "$summary_contents" \
    "Expected summary and log files to match after a successful step."
}

test_run_claude_step_propagates_nonzero_stub_exit_code() {
  load_execute_environment
  setup_execute_fixture
  write_claude_stub "$CLAUDE_ARGS_FILE" "$CLAUDE_STDIN_FILE" 7

  invoke_run_claude_step

  assert_exit_code 7 "$RUN_CLAUDE_STATUS" \
    "Expected run_claude_step to surface the underlying claude CLI exit code so the retry loop can react."
}

run_test_suite
