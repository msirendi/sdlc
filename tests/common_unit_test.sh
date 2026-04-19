#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"
# shellcheck source=orchestrator/lib/common.sh
source "$REPO_ROOT/orchestrator/lib/common.sh"

test_sdlc_lookup_kv_returns_default_when_array_is_empty() {
  local value=""
  local EMPTY_ARRAY=()
  # shellcheck disable=SC2034
  value=$(sdlc_lookup_kv EMPTY_ARRAY "03-implement.md" "fallback")
  assert_equals "fallback" "$value" "Expected sdlc_lookup_kv to return the fallback when the array is empty."
}

test_sdlc_lookup_kv_returns_default_when_key_missing() {
  local value=""
  local SAMPLE_KV=("02-technical-spec.md=1800" "03-implement.md=7200")
  # shellcheck disable=SC2034
  value=$(sdlc_lookup_kv SAMPLE_KV "99-missing.md" "1200")
  assert_equals "1200" "$value" "Expected sdlc_lookup_kv to return the fallback when the key is missing."
}

test_sdlc_lookup_kv_returns_value_for_present_key() {
  local value=""
  local SAMPLE_KV=("02-technical-spec.md=1800" "11-ultra-review.md=3600")
  # shellcheck disable=SC2034
  value=$(sdlc_lookup_kv SAMPLE_KV "11-ultra-review.md" "1200")
  assert_equals "3600" "$value" "Expected sdlc_lookup_kv to return the configured value for the ultra-review step."
}

test_sdlc_lookup_kv_returns_last_value_when_key_repeats() {
  local value=""
  local SAMPLE_KV=("11-ultra-review.md=3600" "11-ultra-review.md=7200")
  # shellcheck disable=SC2034
  value=$(sdlc_lookup_kv SAMPLE_KV "11-ultra-review.md" "0")
  assert_equals "7200" "$value" "Expected sdlc_lookup_kv to prefer the last assignment so overrides win."
}

test_sdlc_lookup_kv_preserves_values_containing_equals_sign() {
  local value=""
  local SAMPLE_KV=("09-semantic-diff-report.md=.sdlc/reports/semantic_diff_report_*.html=glob")
  # shellcheck disable=SC2034
  value=$(sdlc_lookup_kv SAMPLE_KV "09-semantic-diff-report.md" "")
  assert_equals ".sdlc/reports/semantic_diff_report_*.html=glob" "$value" \
    "Expected sdlc_lookup_kv to preserve '=' characters inside the value portion."
}

test_sdlc_step_mode_detects_automated_mode() {
  local step_file=""
  use_temp_dir
  step_file="$TEST_TEMP_DIR/05-tests.md"
  cat <<'EOF' > "$step_file"
# Step 5 — Implement Thorough Unit and Integration Tests

**Mode:** Automated
EOF
  assert_equals "automated" "$(sdlc_step_mode "$step_file")" "Expected automated mode for Step 5."
}

test_sdlc_step_mode_detects_manual_mode_case_insensitive() {
  local step_file=""
  use_temp_dir
  step_file="$TEST_TEMP_DIR/15-merge.md"
  cat <<'EOF' > "$step_file"
# Step 15 — Merge

**Mode:** MANUAL
EOF
  assert_equals "manual" "$(sdlc_step_mode "$step_file")" "Expected manual mode regardless of case."
}

test_sdlc_step_mode_returns_unknown_when_mode_line_missing() {
  local step_file=""
  use_temp_dir
  step_file="$TEST_TEMP_DIR/no-mode.md"
  printf '# Step without a mode line\n' > "$step_file"
  assert_equals "unknown" "$(sdlc_step_mode "$step_file")" "Expected unknown mode when the Mode line is absent."
}

test_sdlc_step_mode_uses_first_mode_line_only() {
  local step_file=""
  use_temp_dir
  step_file="$TEST_TEMP_DIR/two-modes.md"
  cat <<'EOF' > "$step_file"
# Example
**Mode:** automated
Body talks about later mode lines.
**Mode:** manual
EOF
  assert_equals "automated" "$(sdlc_step_mode "$step_file")" \
    "Expected sdlc_step_mode to read only the first Mode line."
}

test_sdlc_git_has_non_log_changes_returns_false_for_clean_tree() {
  local repo_dir=""
  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"
  create_git_repo "$repo_dir"

  if sdlc_git_has_non_log_changes "$repo_dir"; then
    fail "Expected sdlc_git_has_non_log_changes to be false for a clean working tree."
  fi
}

test_sdlc_git_has_non_log_changes_ignores_log_only_changes() {
  local repo_dir=""
  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"
  create_git_repo "$repo_dir"

  # Seed the .sdlc tree the way run-pipeline.sh does so git's porcelain output
  # scopes untracked paths to .sdlc/logs/ rather than collapsing to .sdlc/.
  mkdir -p "$repo_dir/.sdlc/artifacts" "$repo_dir/.sdlc/reports"
  : > "$repo_dir/.sdlc/artifacts/.keep"
  : > "$repo_dir/.sdlc/reports/.keep"
  git -C "$repo_dir" -c user.email=t@t -c user.name=t \
    add .sdlc/artifacts/.keep .sdlc/reports/.keep >/dev/null
  git -C "$repo_dir" -c user.email=t@t -c user.name=t \
    commit -q -m "seed" >/dev/null

  mkdir -p "$repo_dir/.sdlc/logs/20260419-120000"
  printf 'fresh log line\n' > "$repo_dir/.sdlc/logs/20260419-120000/orchestrator.log"

  if sdlc_git_has_non_log_changes "$repo_dir"; then
    fail "Expected sdlc_git_has_non_log_changes to ignore changes confined to .sdlc/logs/."
  fi
}

test_sdlc_git_has_non_log_changes_detects_artifact_changes() {
  local repo_dir=""
  use_temp_dir
  repo_dir="$TEST_TEMP_DIR/repo"
  create_git_repo "$repo_dir"
  mkdir -p "$repo_dir/.sdlc/artifacts"
  printf 'spec body\n' > "$repo_dir/.sdlc/artifacts/technical-spec.md"

  if ! sdlc_git_has_non_log_changes "$repo_dir"; then
    fail "Expected sdlc_git_has_non_log_changes to detect new artifacts outside .sdlc/logs/."
  fi
}

test_sdlc_run_with_timeout_returns_command_exit_code_when_no_timeout() {
  set +e
  sdlc_run_with_timeout "" bash -c 'exit 7'
  local status=$?
  set -e
  assert_exit_code 7 "$status" "Expected sdlc_run_with_timeout to forward the command's exit code when no timeout is set."
}

test_sdlc_run_with_timeout_returns_124_when_command_exceeds_timeout() {
  if ! command -v gtimeout >/dev/null 2>&1 && ! command -v timeout >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    # The helper degrades to direct execution on minimal systems; skip rather than fabricate.
    printf 'skipping timeout enforcement test: no timeout backend available\n' >&2
    return 0
  fi

  set +e
  sdlc_run_with_timeout 1 bash -c 'sleep 5'
  local status=$?
  set -e
  assert_exit_code 124 "$status" "Expected sdlc_run_with_timeout to return 124 when the command exceeds the timeout."
}

run_test_suite
