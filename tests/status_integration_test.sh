#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"

test_status_command_failed_run_marks_failed_and_skipped_steps() {
  local repo_dir=""
  local run_dir=""
  local expected_logs_path=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  run_dir=$(create_run_dir "$repo_dir" "20260413-142531")
  expected_logs_path=$(canonicalize_path "$run_dir")
  write_manifest "$run_dir" "$repo_dir" \
    "01-branch-setup.md" \
    "02-technical-spec.md" \
    "03-implement.md"
  write_orchestrator_log "$run_dir" "fixture-repo" "287" "02-technical-spec.md" \
    "01-branch-setup.md"

  capture_command "$repo_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 0 "$CAPTURED_STATUS" "Expected a valid failed run summary to exit successfully."
  assert_contains "$CAPTURED_OUTPUT" "Run ID: 20260413-142531" "Expected the output to show the latest run ID."
  assert_contains "$CAPTURED_OUTPUT" "Repository: fixture-repo" "Expected the output to show the logged repository name."
  assert_contains "$CAPTURED_OUTPUT" "  ${CHECK_MARK} completed 01-branch-setup.md" "Expected completed steps to be marked completed."
  assert_contains "$CAPTURED_OUTPUT" "  ${CROSS_MARK} failed 02-technical-spec.md" "Expected the halted step to be marked failed."
  assert_contains "$CAPTURED_OUTPUT" "  ${SKIP_MARK} skipped 03-implement.md" "Expected later planned steps to be marked skipped."
  assert_contains "$CAPTURED_OUTPUT" "Elapsed: 4m 47s" "Expected elapsed seconds to be humanized."
  assert_contains "$CAPTURED_OUTPUT" "Logs: $expected_logs_path" "Expected the output to show the log directory."
}

test_status_command_from_nested_directory_uses_repo_root_and_manifest_fallback_name() {
  local repo_dir=""
  local nested_dir=""
  local run_dir=""
  local expected_logs_path=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/example-repo"
  nested_dir="$repo_dir/src/nested"

  create_git_repo "$repo_dir"
  mkdir -p "$nested_dir"
  run_dir=$(create_run_dir "$repo_dir" "20260413-142531")
  expected_logs_path=$(canonicalize_path "$run_dir")
  write_manifest "$run_dir" "$repo_dir" \
    "02-technical-spec.md" \
    "03-implement.md"
  write_orchestrator_log "$run_dir" "" "61" "" \
    "02-technical-spec.md" \
    "03-implement.md"

  capture_command "$nested_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 0 "$CAPTURED_STATUS" "Expected nested invocations inside the repo to succeed."
  assert_contains "$CAPTURED_OUTPUT" "Repository: example-repo" "Expected repository name fallback to use the manifest path basename."
  assert_contains "$CAPTURED_OUTPUT" "  ${CHECK_MARK} completed 02-technical-spec.md" "Expected completed steps to render from a nested directory."
  assert_contains "$CAPTURED_OUTPUT" "Elapsed: 1m 1s" "Expected elapsed time to be shown for nested invocation."
  assert_contains "$CAPTURED_OUTPUT" "Logs: $expected_logs_path" "Expected nested invocation to resolve the repo-root logs directory."
}

test_status_command_incomplete_run_reports_unavailable_elapsed() {
  local repo_dir=""
  local run_dir=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  run_dir=$(create_run_dir "$repo_dir" "20260413-142531")
  write_manifest "$run_dir" "$repo_dir" \
    "02-technical-spec.md" \
    "03-implement.md"
  write_orchestrator_log "$run_dir" "fixture-repo" "" "" \
    "02-technical-spec.md"

  capture_command "$repo_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 0 "$CAPTURED_STATUS" "Expected incomplete runs to still report status successfully."
  assert_contains "$CAPTURED_OUTPUT" "Elapsed: unavailable" "Expected incomplete runs to report unavailable elapsed time."
  assert_contains "$CAPTURED_OUTPUT" "Note: the latest run may still be in progress or was interrupted." "Expected incomplete runs to explain why elapsed time is unavailable."
  assert_contains "$CAPTURED_OUTPUT" "  ${SKIP_MARK} skipped 03-implement.md" "Expected unfinished planned steps to remain skipped."
}

test_status_command_missing_manifest_in_latest_run_exits_nonzero() {
  local repo_dir=""
  local older_run_dir=""
  local latest_run_dir=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  older_run_dir=$(create_run_dir "$repo_dir" "20260413-142531")
  latest_run_dir=$(create_run_dir "$repo_dir" "20260413-142532")
  write_manifest "$older_run_dir" "$repo_dir" "02-technical-spec.md"
  write_orchestrator_log "$older_run_dir" "fixture-repo" "59" "" "02-technical-spec.md"
  write_orchestrator_log "$latest_run_dir" "fixture-repo" "61" "" "02-technical-spec.md"

  capture_command "$repo_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 1 "$CAPTURED_STATUS" "Expected the latest malformed run to exit non-zero."
  assert_contains "$CAPTURED_OUTPUT" "Latest run 20260413-142532 is missing" "Expected a clear missing-manifest error."
}

test_status_command_no_runs_found_exits_zero() {
  local repo_dir=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  capture_command "$repo_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 0 "$CAPTURED_STATUS" "Expected repositories without runs to exit successfully."
  assert_equals "No pipeline runs found." "$CAPTURED_OUTPUT" "Expected the no-run message to match the contract."
}

test_status_command_outside_git_repo_exits_nonzero() {
  use_temp_dir

  capture_command "$TEST_TEMP_DIR" bash "$STATUS_SCRIPT"

  assert_exit_code 1 "$CAPTURED_STATUS" "Expected non-git directories to fail."
  assert_contains "$CAPTURED_OUTPUT" "is not inside a git repository." "Expected a clear outside-repo error."
}

test_status_command_successful_run_prints_summary() {
  local repo_dir=""
  local run_dir=""
  local expected_logs_path=""

  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"

  create_git_repo "$repo_dir"
  run_dir=$(create_run_dir "$repo_dir" "20260413-142531")
  expected_logs_path=$(canonicalize_path "$run_dir")
  write_manifest "$run_dir" "$repo_dir" \
    "02-technical-spec.md" \
    "03-implement.md"
  write_orchestrator_log "$run_dir" "fixture-repo" "3661" "" \
    "02-technical-spec.md" \
    "03-implement.md"

  capture_command "$repo_dir" bash "$STATUS_SCRIPT"

  assert_exit_code 0 "$CAPTURED_STATUS" "Expected successful runs to exit successfully."
  assert_contains "$CAPTURED_OUTPUT" "Run ID: 20260413-142531" "Expected the latest run ID in the summary."
  assert_contains "$CAPTURED_OUTPUT" "Repository: fixture-repo" "Expected the repository name in the summary."
  assert_contains "$CAPTURED_OUTPUT" "  ${CHECK_MARK} completed 02-technical-spec.md" "Expected completed step output for the first planned step."
  assert_contains "$CAPTURED_OUTPUT" "  ${CHECK_MARK} completed 03-implement.md" "Expected completed step output for the second planned step."
  assert_contains "$CAPTURED_OUTPUT" "Elapsed: 1h 1m 1s" "Expected elapsed time to be formatted in hours, minutes, and seconds."
  assert_contains "$CAPTURED_OUTPUT" "Logs: $expected_logs_path" "Expected the summary to show the log directory."
  assert_not_contains "$CAPTURED_OUTPUT" "Note: the latest run may still be in progress or was interrupted." "Did not expect the incomplete-run note for a completed run."
}

run_test_suite
