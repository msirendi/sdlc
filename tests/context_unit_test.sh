#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/testlib.sh
source "$TESTS_DIR/testlib.sh"
# shellcheck source=orchestrator/lib/context.sh
source "$REPO_ROOT/orchestrator/lib/context.sh"

context_fixture() {
  use_temp_dir
  SUMMARY_FIXTURE="$TEST_TEMP_DIR/summary.md"
  CONTEXT_FIXTURE="$TEST_TEMP_DIR/pipeline-context.md"
  : > "$SUMMARY_FIXTURE"
  : > "$CONTEXT_FIXTURE"
}

test_update_context_appends_step_header_and_summary_body() {
  context_fixture
  printf '# Summary body\nLine one\n' > "$SUMMARY_FIXTURE"
  printf 'prior context block\n' >> "$CONTEXT_FIXTURE"

  update_context "12-ultra-review.md" "$SUMMARY_FIXTURE" "$CONTEXT_FIXTURE"

  local contents
  contents=$(cat "$CONTEXT_FIXTURE")
  assert_contains "$contents" "prior context block" "Expected existing context to be preserved."
  assert_contains "$contents" "## Completed: 12-ultra-review.md" \
    "Expected the completed step header to be appended."
  assert_contains "$contents" "# Summary body" "Expected the summary body to be appended verbatim."
  assert_contains "$contents" "Line one" "Expected every line of the summary to be appended."
}

test_update_context_writes_placeholder_when_summary_is_empty() {
  context_fixture
  : > "$SUMMARY_FIXTURE"

  update_context "02-technical-spec.md" "$SUMMARY_FIXTURE" "$CONTEXT_FIXTURE"

  local contents
  contents=$(cat "$CONTEXT_FIXTURE")
  assert_contains "$contents" "## Completed: 02-technical-spec.md" \
    "Expected the header to be appended even when the summary is empty."
  assert_contains "$contents" "No summary file was captured." \
    "Expected a placeholder line when the summary file has no content."
}

test_update_context_truncates_when_context_exceeds_24kb() {
  context_fixture
  # Seed the context well past the 24000-byte ceiling so truncation runs.
  local filler
  filler=$(printf 'x%.0s' $(seq 1 30000))
  printf '%s\n' "$filler" > "$CONTEXT_FIXTURE"
  printf 'fresh summary line\n' > "$SUMMARY_FIXTURE"

  update_context "04-implement.md" "$SUMMARY_FIXTURE" "$CONTEXT_FIXTURE"

  local size
  size=$(wc -c < "$CONTEXT_FIXTURE" | tr -d ' ')
  if [[ "$size" -gt 24000 ]]; then
    fail "Expected context file to be truncated below 24000 bytes but it was $size bytes."
  fi

  # The freshest content (the appended summary) must survive the tail-cut.
  assert_contains "$(cat "$CONTEXT_FIXTURE")" "fresh summary line" \
    "Expected truncation to keep the most recent summary content."
  assert_contains "$(cat "$CONTEXT_FIXTURE")" "## Completed: 04-implement.md" \
    "Expected truncation to keep the most recent step header."
}

test_update_context_does_not_truncate_when_context_is_small() {
  context_fixture
  printf 'a small seed\n' > "$CONTEXT_FIXTURE"
  printf 'a small summary\n' > "$SUMMARY_FIXTURE"

  update_context "05-agents-md-check.md" "$SUMMARY_FIXTURE" "$CONTEXT_FIXTURE"

  local contents
  contents=$(cat "$CONTEXT_FIXTURE")
  assert_contains "$contents" "a small seed" \
    "Expected small context files to retain their original seed content."
  assert_contains "$contents" "a small summary" \
    "Expected small context files to retain the appended summary content."
}

run_test_suite
