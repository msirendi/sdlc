#!/usr/bin/env bash
set -euo pipefail

# These tests pin the contract between Step 6 (run-tests) and the orchestrator's
# 06↔07 loop driver. The orchestrator decides whether to invoke Step 7 by
# parsing the first `Result:` line out of .sdlc/artifacts/test-results.md. If
# this parse drifts, the loop will either skip needed fix iterations or run
# them forever — both are silent correctness failures, so they are pinned here.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"
# shellcheck source=orchestrator/lib/test_fix_loop.sh
source "$REPO_ROOT/orchestrator/lib/test_fix_loop.sh"

results_fixture() {
  use_temp_dir
  RESULTS_FIXTURE="$TEST_TEMP_DIR/test-results.md"
  : > "$RESULTS_FIXTURE"
}

test_sdlc_test_results_status_returns_unknown_when_path_is_empty() {
  results_fixture
  assert_equals "UNKNOWN" "$(sdlc_test_results_status "")" \
    "Expected UNKNOWN when the results path is empty so the loop never silently skips Step 7."
}

test_sdlc_test_results_status_returns_unknown_when_file_is_missing() {
  results_fixture
  rm -f "$RESULTS_FIXTURE"
  assert_equals "UNKNOWN" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected UNKNOWN when the report file does not exist."
}

test_sdlc_test_results_status_returns_unknown_when_marker_line_absent() {
  results_fixture
  cat <<'EOF' > "$RESULTS_FIXTURE"
# Test Results
No Result line here at all.
EOF
  assert_equals "UNKNOWN" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected UNKNOWN when the report omits the parseable Result: marker."
}

test_sdlc_test_results_status_recognizes_pass_marker() {
  results_fixture
  cat <<'EOF' > "$RESULTS_FIXTURE"
# Test Results

Result: PASS
Run at: 2026-04-20T12:00:00Z
EOF
  assert_equals "PASS" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected PASS when the first Result: line reads PASS."
}

test_sdlc_test_results_status_recognizes_fail_marker() {
  results_fixture
  cat <<'EOF' > "$RESULTS_FIXTURE"
# Test Results

Result: FAIL
Run at: 2026-04-20T12:00:00Z
EOF
  assert_equals "FAIL" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected FAIL when the first Result: line reads FAIL."
}

test_sdlc_test_results_status_is_case_insensitive() {
  results_fixture
  cat <<'EOF' > "$RESULTS_FIXTURE"
result: pass
EOF
  assert_equals "PASS" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected lowercase 'result: pass' to be treated identically to PASS so cosmetic case never breaks the loop."
}

test_sdlc_test_results_status_uses_only_first_result_line() {
  results_fixture
  # If a later iteration overwrites the report, the first Result: line is the
  # authoritative one. Pin this so multi-section reports (e.g., a per-iteration
  # appendix) cannot accidentally tip the orchestrator's decision.
  cat <<'EOF' > "$RESULTS_FIXTURE"
Result: FAIL

## Appendix
Result: PASS
EOF
  assert_equals "FAIL" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected the parser to consider only the first Result: line so appendices cannot override the headline status."
}

test_sdlc_test_results_status_tolerates_leading_whitespace() {
  results_fixture
  printf '   Result: PASS\n' > "$RESULTS_FIXTURE"
  assert_equals "PASS" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected leading whitespace before 'Result:' to be tolerated."
}

test_sdlc_test_results_status_treats_unfamiliar_marker_value_as_unknown() {
  results_fixture
  printf 'Result: maybe\n' > "$RESULTS_FIXTURE"
  assert_equals "UNKNOWN" "$(sdlc_test_results_status "$RESULTS_FIXTURE")" \
    "Expected unfamiliar Result: values to fall through to UNKNOWN rather than be silently treated as PASS."
}

run_test_suite