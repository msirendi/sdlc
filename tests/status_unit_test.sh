#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"
# shellcheck source=orchestrator/status.sh
source "$STATUS_SCRIPT"

test_array_contains_returns_failure_for_missing_value() {
  if array_contains "06-run-tests.md" "02-technical-spec.md" "03-implement.md" "05-tests.md"; then
    fail "Expected array_contains to return non-zero for a missing value."
  fi
}

test_array_contains_returns_success_for_present_value() {
  if ! array_contains "03-implement.md" "02-technical-spec.md" "03-implement.md" "05-tests.md"; then
    fail "Expected array_contains to return zero for a present value."
  fi
}

test_find_latest_run_dir_returns_failure_when_logs_dir_missing() {
  use_temp_dir

  if find_latest_run_dir "$TEST_TEMP_DIR/does-not-exist" >/dev/null 2>&1; then
    fail "Expected find_latest_run_dir to fail when the logs directory is absent."
  fi
}

test_find_latest_run_dir_returns_newest_lexical_entry() {
  local repo_dir=""
  local latest_run_dir=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  create_run_dir "$repo_dir" "20260413-141706" >/dev/null
  create_run_dir "$repo_dir" "20260413-142531" >/dev/null
  create_run_dir "$repo_dir" "20260413-141926" >/dev/null

  latest_run_dir=$(find_latest_run_dir "$repo_dir/.sdlc/logs")

  assert_equals "$repo_dir/.sdlc/logs/20260413-142531" "$latest_run_dir" "Expected the lexically newest run directory."
}

test_format_duration_formats_hours_minutes_and_seconds() {
  local formatted=""

  formatted=$(format_duration 3661)

  assert_equals "1h 1m 1s" "$formatted" "Expected hour-level durations to include hours, minutes, and seconds."
}

test_format_duration_formats_minutes_and_seconds() {
  local formatted=""

  formatted=$(format_duration 61)

  assert_equals "1m 1s" "$formatted" "Expected minute-level durations to include minutes and seconds."
}

test_format_duration_formats_zero_seconds() {
  local formatted=""

  formatted=$(format_duration 0)

  assert_equals "0s" "$formatted" "Expected zero seconds to render as 0s."
}

test_parse_manifest_extracts_repo_path_and_planned_steps_only() {
  local run_dir=""
  local actual_steps=""
  local expected_steps=""

  use_temp_dir
  run_dir="$TEST_TEMP_DIR/run"
  mkdir -p "$run_dir"

  write_manifest "$run_dir" "/tmp/example-repo" \
    "02-technical-spec.md" \
    "03-implement.md" \
    "04-agents-md-check.md"

  parse_manifest "$run_dir/pipeline-manifest.md"

  actual_steps=$(join_array PLANNED_STEPS)
  expected_steps=$(join_lines \
    "02-technical-spec.md" \
    "03-implement.md" \
    "04-agents-md-check.md")

  assert_equals "/tmp/example-repo" "$MANIFEST_REPO_PATH" "Expected parse_manifest to extract the repository path."
  assert_equals "$expected_steps" "$actual_steps" "Expected parse_manifest to capture only planned steps."
}

test_parse_manifest_returns_empty_steps_when_section_is_missing() {
  local manifest_file=""
  local actual_steps=""

  use_temp_dir
  manifest_file="$TEST_TEMP_DIR/pipeline-manifest.md"

  cat <<'EOF' > "$manifest_file"
# Pipeline Run Manifest

- Repository: `/tmp/example-repo`
- Task file: `/tmp/example-repo/.sdlc/task.md`
EOF

  parse_manifest "$manifest_file"
  actual_steps=$(join_array PLANNED_STEPS)

  assert_equals "/tmp/example-repo" "$MANIFEST_REPO_PATH" "Expected parse_manifest to retain the repository path."
  assert_equals "" "$actual_steps" "Expected parse_manifest to leave PLANNED_STEPS empty when the section is absent."
}

test_parse_orchestrator_log_collects_completed_failed_and_elapsed_data() {
  local log_file=""
  local actual_completed=""
  local expected_completed=""

  use_temp_dir
  log_file="$TEST_TEMP_DIR/orchestrator.log"

  cat <<'EOF' > "$log_file"
[2026-04-13 14:25:31] [INFO] Repository: fixture-repo
[2026-04-13 14:25:31] [ERROR] Step 02-technical-spec.md reported BLOCKED.
[2026-04-13 14:25:31] [WARN] Validation failed for 02-technical-spec.md.
[2026-04-13 14:25:31] [INFO] Completed 02-technical-spec.md
[2026-04-13 14:30:54] [INFO] Completed 03-implement.md
[2026-04-13 14:24:14] [ERROR] Pipeline halted at 04-agents-md-check.md
[2026-04-13 14:24:14] [INFO] Run complete: 2 succeeded, 1 failed, 287s elapsed.
EOF

  parse_orchestrator_log "$log_file"
  actual_completed=$(join_array COMPLETED_STEPS)
  expected_completed=$(join_lines "02-technical-spec.md" "03-implement.md")

  assert_equals "fixture-repo" "$REPO_NAME" "Expected parse_orchestrator_log to extract the repository name."
  assert_equals "$expected_completed" "$actual_completed" "Expected parse_orchestrator_log to preserve completed steps in order."
  assert_equals "04-agents-md-check.md" "$FAILED_STEP" "Expected parse_orchestrator_log to capture the halted step."
  assert_equals "287" "$ELAPSED_SECONDS" "Expected parse_orchestrator_log to extract elapsed seconds."
}

test_parse_orchestrator_log_leaves_elapsed_unset_for_incomplete_runs() {
  local log_file=""
  local actual_completed=""

  use_temp_dir
  log_file="$TEST_TEMP_DIR/orchestrator.log"

  cat <<'EOF' > "$log_file"
[2026-04-13 14:25:31] [INFO] Repository: fixture-repo
[2026-04-13 14:30:54] [INFO] Completed 02-technical-spec.md
EOF

  parse_orchestrator_log "$log_file"
  actual_completed=$(join_array COMPLETED_STEPS)

  assert_equals "fixture-repo" "$REPO_NAME" "Expected parse_orchestrator_log to preserve the repository name."
  assert_equals "02-technical-spec.md" "$actual_completed" "Expected parse_orchestrator_log to preserve completed steps."
  assert_equals "" "$FAILED_STEP" "Expected no failed step when the run has not halted."
  assert_equals "" "$ELAPSED_SECONDS" "Expected elapsed seconds to remain unset when the run is incomplete."
}

run_test_suite
