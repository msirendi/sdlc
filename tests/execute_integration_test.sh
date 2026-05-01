#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"

# These integration tests exercise run_codex_step end-to-end with a stubbed
# `codex` CLI on PATH. The stub records its argv and stdin so tests can assert
# on how the Codex CLI runner is invoked.

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
  STEP_FILE="$TEST_TEMP_DIR/03-tests.md"
  TASK_FILE="$TEST_TEMP_DIR/task.md"
  CONTEXT_FILE="$TEST_TEMP_DIR/pipeline-context.md"
  STEP_LOG_FILE="$TEST_TEMP_DIR/step.log"
  STEP_SUMMARY_FILE="$TEST_TEMP_DIR/step_summary.md"
  CODEX_ARGS_FILE="$TEST_TEMP_DIR/codex.args"
  CODEX_STDIN_FILE="$TEST_TEMP_DIR/codex.stdin"
  # The sdlc_log helper appends to $LOG_FILE when it is set, so route those
  # orchestrator-style log lines away from the test assertions.
  LOG_FILE="$TEST_TEMP_DIR/orchestrator.log"

  create_git_repo "$FAKE_REPO"
  mkdir -p "$FAKE_BIN"

  cat <<'EOF' > "$STEP_FILE"
# Step 3 — Author Tests From the Technical Spec (Before Implementation)

**Mode:** Automated
Author unit and integration tests against the spec.
EOF

  cat <<'EOF' > "$TASK_FILE"
# Feature: Validate staged Codex runner
Build high-value tests that exercise the Codex CLI runner path.
EOF

  : > "$CONTEXT_FILE"
  : > "$STEP_LOG_FILE"
  : > "$STEP_SUMMARY_FILE"
  : > "$LOG_FILE"

  # Default stub records argv + stdin and writes a READY final response to the
  # --output-last-message path. Individual tests can overwrite it (e.g., to
  # simulate a failing codex invocation).
  write_codex_stub "$CODEX_ARGS_FILE" "$CODEX_STDIN_FILE" 0
  PATH="$FAKE_BIN:$PATH"
  export PATH

  STEP_APPROVAL_POLICIES=()
  STEP_SANDBOX_MODES=()
  CODEX_EXTRA_ARGS=""
}

write_codex_stub() {
  local args_file="$1"
  local stdin_file="$2"
  local exit_code="$3"

  cat <<STUB > "$FAKE_BIN/codex"
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$args_file"
cat > "$stdin_file"

summary_file=""
previous_arg=""
for arg in "\$@"; do
  if [[ "\$previous_arg" == "--output-last-message" || "\$previous_arg" == "-o" ]]; then
    summary_file="\$arg"
    previous_arg=""
    continue
  fi
  previous_arg="\$arg"
done

response='1. Accomplished
- Step executed under stub.
5. Status: READY
'
if [[ -n "\$summary_file" ]]; then
  printf '%s' "\$response" > "\$summary_file"
fi
printf 'codex stub progress\n'
exit $exit_code
STUB
  chmod +x "$FAKE_BIN/codex"
}

invoke_run_codex_step() {
  # Use a generous timeout so sdlc_run_with_timeout does not interfere with fast
  # stub invocations, but keep it short enough to catch wedged tests.
  set +e
  run_codex_step \
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
  RUN_CODEX_STATUS="$status"
}

test_run_codex_step_invokes_codex_with_configured_flags() {
  load_execute_environment
  setup_execute_fixture
  CODEX_MODEL="azure/gpt-5.5"
  CODEX_EFFORT="xhigh"
  CODEX_APPROVAL_POLICY="never"
  CODEX_SANDBOX_MODE="danger-full-access"

  invoke_run_codex_step
  assert_exit_code 0 "$RUN_CODEX_STATUS" "Expected run_codex_step to return the stub's exit code."

  local args
  args=$(cat "$CODEX_ARGS_FILE")
  assert_contains "$args" "exec" "Expected codex exec to be used for non-interactive runs."
  assert_contains "$args" "--model"$'\n'"azure/gpt-5.5" \
    "Expected --model to be followed by the configured CODEX_MODEL."
  assert_contains "$args" "--ask-for-approval"$'\n'"never" \
    "Expected --ask-for-approval to be followed by the configured CODEX_APPROVAL_POLICY."
  assert_contains "$args" "--sandbox"$'\n'"danger-full-access" \
    "Expected --sandbox to be followed by the configured CODEX_SANDBOX_MODE."
  assert_contains "$args" "--cd"$'\n'"$FAKE_REPO" \
    "Expected --cd to point Codex at the target repository."
  assert_contains "$args" "--output-last-message"$'\n'"$STEP_SUMMARY_FILE" \
    "Expected --output-last-message to capture the final Codex response."
  assert_contains "$args" "--config"$'\n'"model_provider=\"litellm\"" \
    "Expected the LiteLLM provider to be selected through Codex config."
  assert_contains "$args" "--config"$'\n'"model_reasoning_effort=\"xhigh\"" \
    "Expected xhigh reasoning effort to be passed through Codex config."
  assert_contains "$args" "--config"$'\n'"api_base_url=\"https://litellm.clarium.ai/v1\"" \
    "Expected the LiteLLM proxy URL to be passed as the root Codex API base URL."
  assert_contains "$args" "--config"$'\n'"model_providers.litellm.base_url=\"https://litellm.clarium.ai/v1\"" \
    "Expected the LiteLLM proxy URL to be passed through Codex config."
}

test_run_codex_step_applies_per_step_approval_policy_override() {
  load_execute_environment
  setup_execute_fixture
  STEP_APPROVAL_POLICIES=("03-tests.md=on-request")

  invoke_run_codex_step
  assert_exit_code 0 "$RUN_CODEX_STATUS" "Expected override invocation to succeed."

  local args
  args=$(cat "$CODEX_ARGS_FILE")
  assert_contains "$args" "--ask-for-approval"$'\n'"on-request" \
    "Expected per-step STEP_APPROVAL_POLICIES entry to override the default policy."
  assert_not_contains "$args" "--ask-for-approval"$'\n'"never" \
    "Did not expect never to be passed once the per-step override was configured."
}

test_run_codex_step_forwards_codex_extra_args() {
  load_execute_environment
  setup_execute_fixture
  CODEX_EXTRA_ARGS="--skip-git-repo-check --ephemeral"

  invoke_run_codex_step
  assert_exit_code 0 "$RUN_CODEX_STATUS" "Expected invocation with extra args to succeed."

  local args
  args=$(cat "$CODEX_ARGS_FILE")
  assert_contains "$args" "--skip-git-repo-check" \
    "Expected CODEX_EXTRA_ARGS to forward --skip-git-repo-check."
  assert_contains "$args" "--ephemeral" \
    "Expected CODEX_EXTRA_ARGS to forward --ephemeral."
}

test_run_codex_step_passes_full_prompt_on_stdin() {
  load_execute_environment
  setup_execute_fixture

  invoke_run_codex_step
  assert_exit_code 0 "$RUN_CODEX_STATUS" "Expected invocation to succeed."

  local stdin_contents
  stdin_contents=$(cat "$CODEX_STDIN_FILE")
  assert_contains "$stdin_contents" "Repository root: $FAKE_REPO" \
    "Expected the prompt to identify the repository root."
  assert_contains "$stdin_contents" "Build high-value tests that exercise the Codex CLI runner path." \
    "Expected the task description to be injected into the prompt."
  assert_contains "$stdin_contents" "Author unit and integration tests against the spec." \
    "Expected the step instructions to be injected into the prompt."
  assert_contains "$stdin_contents" "## Final Response Format" \
    "Expected the canonical final response format to be included in the prompt."
}

test_run_codex_step_captures_final_message_and_logs_progress() {
  load_execute_environment
  setup_execute_fixture

  invoke_run_codex_step
  assert_exit_code 0 "$RUN_CODEX_STATUS" "Expected the stubbed step to succeed."

  local log_contents summary_contents
  log_contents=$(cat "$STEP_LOG_FILE")
  summary_contents=$(cat "$STEP_SUMMARY_FILE")

  assert_contains "$log_contents" "codex stub progress" \
    "Expected the step log to contain Codex progress output."
  assert_contains "$log_contents" "Status: READY" \
    "Expected the step log to include the stub's final status line after execution."
  assert_contains "$summary_contents" "Status: READY" \
    "Expected the summary file to contain the final Codex message for downstream validation."
  assert_not_contains "$summary_contents" "codex stub progress" \
    "Did not expect transient progress output to contaminate the summary file."
}

test_run_codex_step_propagates_nonzero_stub_exit_code() {
  load_execute_environment
  setup_execute_fixture
  write_codex_stub "$CODEX_ARGS_FILE" "$CODEX_STDIN_FILE" 7

  invoke_run_codex_step

  assert_exit_code 7 "$RUN_CODEX_STATUS" \
    "Expected run_codex_step to surface the underlying codex CLI exit code so the retry loop can react."
}

run_test_suite
