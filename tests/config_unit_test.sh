#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"

load_config() {
  # Config is designed to be sourced once per shell and can rely on SDLC_HOME.
  SDLC_HOME="$REPO_ROOT"
  # shellcheck source=orchestrator/config.sh
  source "$REPO_ROOT/orchestrator/config.sh"
  # shellcheck source=orchestrator/lib/common.sh
  source "$REPO_ROOT/orchestrator/lib/common.sh"
}

test_config_defaults_claude_model_to_opus_4_7() {
  load_config
  assert_equals "claude-opus-4-7" "$CLAUDE_MODEL" \
    "Expected Claude runner to default to Opus 4.7 per the staged switch from Codex."
}

test_config_defaults_claude_effort_to_xhigh() {
  load_config
  assert_equals "xhigh" "$CLAUDE_EFFORT" \
    "Expected Claude runner to default to xhigh effort to match the documented pipeline behavior."
}

test_config_defaults_claude_permission_mode_to_accept_edits() {
  load_config
  assert_equals "acceptEdits" "$CLAUDE_PERMISSION_MODE" \
    "Expected acceptEdits as the default permission mode since orchestrated steps commit files."
}

test_config_honors_preset_claude_model_environment_override() {
  local CLAUDE_MODEL="claude-sonnet-4-6"
  load_config
  assert_equals "claude-sonnet-4-6" "$CLAUDE_MODEL" \
    "Expected environment-level CLAUDE_MODEL to win over the default."
}

test_config_step_timeouts_include_ultra_review_entry() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_TIMEOUTS "12-ultra-review.md" "")
  assert_equals "3600" "$value" \
    "Expected Step 12 (ultra-review) to have a 3600s timeout after the renumbering."
}

test_config_step_retry_counts_include_ultra_review_entry() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_RETRY_COUNTS "12-ultra-review.md" "")
  assert_equals "2" "$value" \
    "Expected Step 12 (ultra-review) to be configured with 2 retries."
}

test_config_step_required_patterns_include_ultra_review_artifact() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_REQUIRED_PATTERNS "12-ultra-review.md" "")
  assert_equals ".sdlc/artifacts/ultra-review.md" "$value" \
    "Expected Step 12 to require .sdlc/artifacts/ultra-review.md so validate_step enforces the canonical output."
}

test_config_step_required_patterns_include_test_results_artifact() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_REQUIRED_PATTERNS "06-run-tests.md" "")
  assert_equals ".sdlc/artifacts/test-results.md" "$value" \
    "Expected Step 6 to require .sdlc/artifacts/test-results.md so the test-fix loop has a parseable Result: marker."
}

test_config_test_fix_loop_constants_have_expected_defaults() {
  load_config
  assert_equals "06-run-tests.md" "$TEST_RUN_STEP" \
    "Expected the run-tests step name to be the canonical default."
  assert_equals "07-fix-test-failures.md" "$TEST_FIX_STEP" \
    "Expected the fix-test-failures step name to be the canonical default."
  assert_equals ".sdlc/artifacts/test-results.md" "$TEST_RESULTS_REL" \
    "Expected the test-results artifact path to be canonical."
  assert_equals "3" "$MAX_TEST_FIX_ITERATIONS" \
    "Expected the test-fix loop iteration cap to default to 3."
}

test_config_step_timeouts_for_tests_first_ordering() {
  load_config
  assert_equals "3600" "$(sdlc_lookup_kv STEP_TIMEOUTS "03-tests.md" "")" \
    "Expected Step 3 (tests) to have a 3600s timeout under the test-first ordering."
  assert_equals "7200" "$(sdlc_lookup_kv STEP_TIMEOUTS "04-implement.md" "")" \
    "Expected Step 4 (implement) to inherit the implementation timeout under the test-first ordering."
  assert_equals "5400" "$(sdlc_lookup_kv STEP_TIMEOUTS "07-fix-test-failures.md" "")" \
    "Expected the new Step 7 (fix-test-failures) to have an explicit timeout."
}

test_config_step_timeouts_renumbered_through_step_fifteen() {
  load_config
  # After the renumbering, automated steps go through 15 (rebase). Spot-check
  # each of the renumbered steps has a concrete timeout, not the catch-all default.
  assert_equals "1800" "$(sdlc_lookup_kv STEP_TIMEOUTS "13-push-and-hooks.md" "")" \
    "Expected Step 13 (push-and-hooks) to have a 1800s timeout after renumbering."
  assert_equals "5400" "$(sdlc_lookup_kv STEP_TIMEOUTS "14-fix-ci.md" "")" \
    "Expected Step 14 (fix-ci) to have a 5400s timeout after renumbering."
  assert_equals "2400" "$(sdlc_lookup_kv STEP_TIMEOUTS "15-rebase.md" "")" \
    "Expected Step 15 (rebase) to have a 2400s timeout after renumbering."
}

test_config_step_timeouts_omit_manual_steps() {
  load_config
  # Manual checklist steps (16-merge, 17-cleanup) should fall through to the
  # default, since they are not executed by the orchestrator automatically.
  assert_equals "" "$(sdlc_lookup_kv STEP_TIMEOUTS "16-merge.md" "")" \
    "Expected manual Step 16 to have no explicit timeout entry."
  assert_equals "" "$(sdlc_lookup_kv STEP_TIMEOUTS "17-cleanup.md" "")" \
    "Expected manual Step 17 to have no explicit timeout entry."
}

test_config_heartbeat_interval_has_sensible_default() {
  load_config
  # Heartbeat cadence is user-facing (it controls how often "still running"
  # messages print during long Claude calls). Pin the default so overrides.sh
  # authors can reason about it, and confirm it stays enabled by default.
  assert_equals "120" "$HEARTBEAT_INTERVAL" \
    "Expected HEARTBEAT_INTERVAL to default to 120s so long steps aren't silent."
}

test_config_heartbeat_interval_honors_environment_override() {
  local HEARTBEAT_INTERVAL=30
  load_config
  assert_equals "30" "$HEARTBEAT_INTERVAL" \
    "Expected preset HEARTBEAT_INTERVAL in the environment to override the default."
}

run_test_suite
