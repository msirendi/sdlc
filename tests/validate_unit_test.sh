#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"
# shellcheck source=orchestrator/lib/common.sh
source "$REPO_ROOT/orchestrator/lib/common.sh"
# shellcheck source=orchestrator/lib/validate.sh
source "$REPO_ROOT/orchestrator/lib/validate.sh"

# Validator captures sdlc_log output via LOG_FILE; send it somewhere disposable
# so tests do not bleed log lines into CAPTURED_OUTPUT comparisons.
reset_validate_fixture() {
  use_temp_dir
  REPO_DIR="$TEST_TEMP_DIR/repo"
  LOG_FIXTURE="$TEST_TEMP_DIR/attempt.log"
  SUMMARY_FIXTURE="$TEST_TEMP_DIR/attempt_summary.md"
  LOG_FILE="$TEST_TEMP_DIR/orchestrator.log"
  STEP_REQUIRED_PATTERNS=()
  create_git_repo "$REPO_DIR"
  : > "$LOG_FIXTURE"
  : > "$SUMMARY_FIXTURE"
  : > "$LOG_FILE"
}

write_ready_summary() {
  cat <<'EOF' > "$SUMMARY_FIXTURE"
1. Accomplished
- Did the thing.
2. Files created or modified
- none
3. Commands run and exit codes
- none
4. Issues encountered
- none
5. Status: READY
EOF
}

write_blocked_summary() {
  cat <<'EOF' > "$SUMMARY_FIXTURE"
1. Accomplished
- Stopped early.
5. Status: BLOCKED — downstream dependency unavailable
EOF
}

write_missing_status_summary() {
  cat <<'EOF' > "$SUMMARY_FIXTURE"
1. Accomplished
- Did the thing but forgot to declare status.
EOF
}

test_validate_step_returns_failure_when_log_is_empty() {
  reset_validate_fixture
  write_ready_summary
  : > "$LOG_FIXTURE"

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 1 "$status" "Expected validate_step to fail when the log is empty."
}

test_validate_step_returns_failure_when_summary_missing() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  rm -f "$SUMMARY_FIXTURE"

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 1 "$status" "Expected validate_step to fail when the summary file is absent."
}

test_validate_step_returns_failure_on_blocked_status() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_blocked_summary

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 1 "$status" "Expected validate_step to fail when the summary reports BLOCKED."
  assert_contains "$(cat "$LOG_FILE")" "reported BLOCKED" \
    "Expected validate_step to log that the step reported BLOCKED."
}

test_validate_step_succeeds_on_ready_status_without_required_outputs() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_ready_summary

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 0 "$status" "Expected validate_step to succeed when the summary reports READY."
}

test_validate_step_warns_but_succeeds_when_status_line_missing() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_missing_status_summary

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 0 "$status" "Expected validate_step to succeed when the status line is absent."
  assert_contains "$(cat "$LOG_FILE")" "did not include an explicit READY/BLOCKED status" \
    "Expected validate_step to warn when the summary lacks an explicit status."
}

test_validate_step_fails_when_required_artifact_is_missing() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_ready_summary
  # Mirror the production config entry for Step 12.
  STEP_REQUIRED_PATTERNS=("12-ultra-review.md=.sdlc/artifacts/ultra-review.md")

  set +e
  validate_step "12-ultra-review.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 1 "$status" "Expected validate_step to fail when the required ultra-review artifact is missing."
  assert_contains "$(cat "$LOG_FILE")" "missing required output: .sdlc/artifacts/ultra-review.md" \
    "Expected validate_step to log the missing required artifact path."
}

test_validate_step_succeeds_when_required_artifact_is_present() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_ready_summary
  mkdir -p "$REPO_DIR/.sdlc/artifacts"
  printf '# Ultra review findings\n' > "$REPO_DIR/.sdlc/artifacts/ultra-review.md"
  STEP_REQUIRED_PATTERNS=("12-ultra-review.md=.sdlc/artifacts/ultra-review.md")

  set +e
  validate_step "12-ultra-review.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 0 "$status" "Expected validate_step to succeed when the required ultra-review artifact exists."
}

test_validate_step_matches_required_pattern_with_glob() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  write_ready_summary
  mkdir -p "$REPO_DIR/.sdlc/reports"
  printf '<html></html>' > "$REPO_DIR/.sdlc/reports/semantic_diff_report_SDLC-TEST.html"
  STEP_REQUIRED_PATTERNS=("10-semantic-diff-report.md=.sdlc/reports/semantic_diff_report_*.html")

  set +e
  validate_step "10-semantic-diff-report.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 0 "$status" "Expected validate_step to accept any file matching the required glob pattern."
}

test_validate_step_detects_lowercase_blocked_status() {
  reset_validate_fixture
  printf 'log content\n' > "$LOG_FIXTURE"
  cat <<'EOF' > "$SUMMARY_FIXTURE"
5. Status: blocked - need more input
EOF

  set +e
  validate_step "03-tests.md" "$REPO_DIR" "$LOG_FIXTURE" "$SUMMARY_FIXTURE" >/dev/null
  local status=$?
  set -e
  assert_exit_code 1 "$status" "Expected validate_step to treat lowercase 'blocked' identically to BLOCKED."
}

run_test_suite
