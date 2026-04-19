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
  value=$(sdlc_lookup_kv STEP_TIMEOUTS "11-ultra-review.md" "")
  assert_equals "3600" "$value" \
    "Expected Step 11 (ultra-review) to have a 3600s timeout after the renumbering."
}

test_config_step_retry_counts_include_ultra_review_entry() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_RETRY_COUNTS "11-ultra-review.md" "")
  assert_equals "2" "$value" \
    "Expected Step 11 (ultra-review) to be configured with 2 retries."
}

test_config_step_required_patterns_include_ultra_review_artifact() {
  load_config
  local value
  value=$(sdlc_lookup_kv STEP_REQUIRED_PATTERNS "11-ultra-review.md" "")
  assert_equals ".sdlc/artifacts/ultra-review.md" "$value" \
    "Expected Step 11 to require .sdlc/artifacts/ultra-review.md so validate_step enforces the canonical output."
}

test_config_step_timeouts_renumbered_through_step_fourteen() {
  load_config
  # After the renumbering, automated steps go through 14 (rebase). Spot-check
  # each of the renumbered steps has a concrete timeout, not the catch-all default.
  assert_equals "1800" "$(sdlc_lookup_kv STEP_TIMEOUTS "12-push-and-hooks.md" "")" \
    "Expected Step 12 (push-and-hooks) to have a 1800s timeout after renumbering."
  assert_equals "5400" "$(sdlc_lookup_kv STEP_TIMEOUTS "13-fix-ci.md" "")" \
    "Expected Step 13 (fix-ci) to have a 5400s timeout after renumbering."
  assert_equals "2400" "$(sdlc_lookup_kv STEP_TIMEOUTS "14-rebase.md" "")" \
    "Expected Step 14 (rebase) to have a 2400s timeout after renumbering."
}

test_config_step_timeouts_omit_manual_steps() {
  load_config
  # Manual checklist steps (15-merge, 16-cleanup) should fall through to the
  # default, since they are not executed by the orchestrator automatically.
  assert_equals "" "$(sdlc_lookup_kv STEP_TIMEOUTS "15-merge.md" "")" \
    "Expected manual Step 15 to have no explicit timeout entry."
  assert_equals "" "$(sdlc_lookup_kv STEP_TIMEOUTS "16-cleanup.md" "")" \
    "Expected manual Step 16 to have no explicit timeout entry."
}

run_test_suite
